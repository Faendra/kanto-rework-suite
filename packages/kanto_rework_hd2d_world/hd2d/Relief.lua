local Relief = {}
Relief.__index = Relief

local CELL = 16
local MARGIN_CELLS = 2

function Relief.new(MaterialClassifier)
  return setmetatable({
    MaterialClassifier = MaterialClassifier,
    lastScenes = 0,
    lastCells = 0,
    lastTopRuns = 0,
    lastFrontRuns = 0,
    lastSideFaces = 0,
  }, Relief)
end

local function visibleCellRange(map, proj, ox, oy)
  ox, oy = ox or 0, oy or 0
  local localLeft = proj.camX - ox
  local localTop = proj.bgY - oy
  local x0 = math.floor(localLeft / CELL) - MARGIN_CELLS
  local y0 = math.floor(localTop / CELL) - MARGIN_CELLS
  local x1 = math.ceil((localLeft + proj.vw) / CELL) + MARGIN_CELLS
  local y1 = math.ceil((localTop + proj.vh) / CELL) + MARGIN_CELLS
  x0 = math.max(0, x0)
  y0 = math.max(0, y0)
  x1 = math.min((map.widthCells or 0) - 1, x1)
  y1 = math.min((map.heightCells or 0) - 1, y1)
  return x0, y0, x1, y1
end

local function sameMass(a, b)
  if not (a and b and a.kind == "solid" and b.kind == "solid") then return false end
  if a.massId ~= nil or b.massId ~= nil then return a.massId == b.massId end
  return a.family == b.family and a.heightScale == b.heightScale
end

local function faceFactors(material)
  local family = material and material.family or "mass"
  if family == "structure" then return 0.74, 0.58 end
  if family == "boundary" then return 0.62, 0.49 end
  if family == "landmark" then return 0.69, 0.53 end
  if family == "obstacle" then return 0.77, 0.62 end
  return 0.66, 0.54
end

local function drawTopCell(host, proj, wx, wy, height)
  local sx = wx - proj.camX
  local sy = wy - proj.bgY
  if sx < 0 or sy < 0 or sx + CELL > host.sourceW or sy + CELL > host.sourceH then
    return false
  end
  host.cellQuad:setViewport(sx, sy, CELL, CELL, host.sourceW, host.sourceH)
  local metrics = proj:cellMetrics(wx, wy, CELL, height)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(host.source, host.cellQuad, metrics.x, metrics.y,
                     0, metrics.width / CELL, metrics.height / CELL)
  return true
end

local function drawTopRun(host, proj, wx, wy, cells, height)
  local runW = cells * CELL
  local sx = wx - proj.camX
  local sy = wy - proj.bgY
  if sx < 0 or sy < 0 or sx + runW > host.sourceW or sy + CELL > host.sourceH then
    -- Camera-edge clipping must not stretch a partial texture across a whole
    -- mass. Fall back to complete source cells only for that clipped run.
    local any = false
    for i = 0, cells - 1 do
      any = drawTopCell(host, proj, wx + i * CELL, wy, height) or any
    end
    return any
  end

  host.cellQuad:setViewport(sx, sy, runW, CELL, host.sourceW, host.sourceH)
  local localY = wy - proj.bgY + CELL * 0.5
  local depth = proj:depthScale(localY)
  local centerX, centerY = proj:projectTerrain(wx + runW * 0.5,
                                               wy + CELL * 0.5, height)
  local screenW = runW * depth * proj.scale
  local screenH = CELL * proj.compression * proj.scale
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(host.source, host.cellQuad,
                     centerX - screenW * 0.5,
                     centerY - screenH * 0.5,
                     0, screenW / runW, screenH / CELL)
  return true
end

local function drawFrontRun(host, ctx, proj, map, material, wx0, wx1, wy, height)
  local frontFactor = faceFactors(material)
  local r, g, b, a = host:paletteWallColor(ctx, map, 0.90, frontFactor)
  local ax, ay = proj:projectTerrain(wx0, wy, 0)
  local bx, by = proj:projectTerrain(wx1, wy, 0)
  local tax, tay = proj:projectTerrain(wx0, wy, height)
  local tbx, tby = proj:projectTerrain(wx1, wy, height)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", tax, tay, tbx, tby, bx, by, ax, ay)
end

local function drawSideFace(host, ctx, proj, map, material, wx, wy, height)
  local _, sideFactor = faceFactors(material)
  local r, g, b, a = host:paletteWallColor(ctx, map, 0.82, sideFactor)
  local ax, ay = proj:projectTerrain(wx + CELL, wy, 0)
  local bx, by = proj:projectTerrain(wx + CELL, wy + CELL, 0)
  local tax, tay = proj:projectTerrain(wx + CELL, wy, height)
  local tbx, tby = proj:projectTerrain(wx + CELL, wy + CELL, height)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", tax, tay, tbx, tby, bx, by, ax, ay)
end

function Relief:drawScene(host, ctx, proj, map, ox, oy)
  if not (host and host.source and host.cellQuad and map) then return 0 end
  if not (map.widthCells and map.heightCells) then return 0 end

  ox, oy = ox or 0, oy or 0
  local x0, y0, x1, y1 = visibleCellRange(map, proj, ox, oy)
  if x1 < x0 or y1 < y0 then return 0 end

  local classifier = self.MaterialClassifier
  local lift = proj.relief
  local drawn = 0

  -- Painter order remains far -> near by source row. Within each row,
  -- contiguous cells from the same semantic mass share one top texture run
  -- and one front wall run. The 16x16 collision cell is therefore no longer
  -- the visible unit of facade geometry.
  for cy = y0, y1 do
    local materials = {}
    for cx = x0, x1 do
      local material = classifier.classify(map, cx, cy)
      materials[cx] = material
      if material.kind == "solid" then drawn = drawn + 1 end
    end

    -- Front walls: merge adjacent exposed edges belonging to one mass.
    local cx = x0
    while cx <= x1 do
      local material = materials[cx]
      if material and material.kind == "solid"
         and classifier.frontExposed(map, cx, cy) then
        local runStart, runEnd = cx, cx
        while runEnd + 1 <= x1 do
          local nextMat = materials[runEnd + 1]
          if not sameMass(material, nextMat)
             or not classifier.frontExposed(map, runEnd + 1, cy) then break end
          runEnd = runEnd + 1
        end
        local height = classifier.reliefHeight(material, lift)
        local wy = (cy + 1) * CELL + oy
        drawFrontRun(host, ctx, proj, map, material,
                     runStart * CELL + ox, (runEnd + 1) * CELL + ox,
                     wy, height)
        self.lastFrontRuns = self.lastFrontRuns + 1
        cx = runEnd + 1
      else
        cx = cx + 1
      end
    end

    -- Right/east faces remain cell-segmented because depth changes along Y;
    -- their internal edges are not drawn and the fill is identical per mass.
    for sx = x0, x1 do
      local material = materials[sx]
      if material and material.kind == "solid"
         and classifier.sideExposed(map, sx, cy, 1) then
        local height = classifier.reliefHeight(material, lift)
        drawSideFace(host, ctx, proj, map, material,
                     sx * CELL + ox, cy * CELL + oy, height)
        self.lastSideFaces = self.lastSideFaces + 1
      end
    end

    -- Top surfaces: merge each horizontal span from the same connected mass.
    cx = x0
    while cx <= x1 do
      local material = materials[cx]
      if material and material.kind == "solid" then
        local runStart, runEnd = cx, cx
        while runEnd + 1 <= x1 and sameMass(material, materials[runEnd + 1]) do
          runEnd = runEnd + 1
        end
        local height = classifier.reliefHeight(material, lift)
        if drawTopRun(host, proj, runStart * CELL + ox, cy * CELL + oy,
                      runEnd - runStart + 1, height) then
          self.lastTopRuns = self.lastTopRuns + 1
        end
        cx = runEnd + 1
      else
        cx = cx + 1
      end
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
  return drawn
end

function Relief:draw(host, ctx, proj)
  local state = ctx and ctx.state
  local map = state and state.map
  if not map then return 0 end

  self.lastScenes, self.lastCells = 0, 0
  self.lastTopRuns, self.lastFrontRuns, self.lastSideFaces = 0, 0, 0
  self.lastScenes = self.lastScenes + 1
  self.lastCells = self.lastCells + self:drawScene(host, ctx, proj, map, 0, 0)

  for _, nb in ipairs(state.neighbors or {}) do
    if nb.map then
      self.lastScenes = self.lastScenes + 1
      self.lastCells = self.lastCells
        + self:drawScene(host, ctx, proj, nb.map, nb.ox or 0, nb.oy or 0)
    end
  end
  return self.lastCells
end

return Relief
