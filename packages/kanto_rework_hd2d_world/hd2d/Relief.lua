local Relief = {}
Relief.__index = Relief

local CELL = 16
local MARGIN_CELLS = 2

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function finite(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function normalizeColor(c, fallback)
  if type(c) ~= "table" then return fallback[1], fallback[2], fallback[3] end
  local r, g, b = c[1], c[2], c[3]
  if not (finite(r) and finite(g) and finite(b)) then
    return fallback[1], fallback[2], fallback[3]
  end
  if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
  return r, g, b
end

function Relief.new(MaterialClassifier)
  return setmetatable({
    MaterialClassifier = MaterialClassifier,
    lastScenes = 0,
    lastCells = 0,
    lastTopRuns = 0,
    lastFrontRuns = 0,
    lastSideFaces = 0,
    lastDoorways = 0,
    lastEaves = 0,
    lastCanopies = 0,
    lastMassShadows = 0,
    lastRoofs = 0,
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

function Relief:visibleCellRange(map, proj, ox, oy)
  return visibleCellRange(map, proj, ox, oy)
end

function Relief:resetMetrics()
  self.lastScenes, self.lastCells = 0, 0
  self.lastTopRuns, self.lastFrontRuns, self.lastSideFaces = 0, 0, 0
  self.lastDoorways, self.lastEaves, self.lastCanopies = 0, 0, 0
  self.lastMassShadows, self.lastRoofs = 0, 0
end

local function sameMass(a, b)
  if not (a and b and a.kind == "solid" and b.kind == "solid") then return false end
  if a.massId ~= nil or b.massId ~= nil then return a.massId == b.massId end
  return a.family == b.family and a.heightScale == b.heightScale
end

local function faceFactors(material)
  local family = material and material.family or "mass"
  if family == "structure" then return 0.74, 0.58 end
  if family == "vegetation" then return 0.54, 0.43 end
  if family == "boundary" then return 0.62, 0.49 end
  if family == "landmark" then return 0.69, 0.53 end
  if family == "obstacle" then return 0.77, 0.62 end
  return 0.66, 0.54
end

local function shadowAlpha(material)
  local family = material and material.family or "mass"
  if family == "structure" then return 0.115, 0.24 end
  if family == "vegetation" then return 0.095, 0.20 end
  if family == "landmark" then return 0.080, 0.18 end
  if family == "boundary" then return 0.060, 0.15 end
  return 0.050, 0.12
end

local function paletteTone(host, ctx, map, fromDark, factor, alpha)
  local fallback = { 0.18, 0.20, 0.18 }
  local palette = ctx.paletteFor and ctx.paletteFor(map) or nil
  if type(palette) ~= "table" or #palette == 0 then
    return host:paletteWallColor(ctx, map, alpha, factor)
  end
  local index = clamp(#palette - (fromDark or 1), 1, #palette)
  local r, g, b = normalizeColor(palette[index], fallback)
  factor = factor or 1
  return clamp(r * factor, 0, 1), clamp(g * factor, 0, 1),
         clamp(b * factor, 0, 1), alpha or 1
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

local function drawTexturedRun(host, proj, wx, wy, cells, height,
                               widthScale, heightScale, alpha)
  local runW = cells * CELL
  local sx = wx - proj.camX
  local sy = wy - proj.bgY
  if sx < 0 or sy < 0 or sx + runW > host.sourceW or sy + CELL > host.sourceH then
    return false
  end

  host.cellQuad:setViewport(sx, sy, runW, CELL, host.sourceW, host.sourceH)
  local localY = wy - proj.bgY + CELL * 0.5
  local depth = proj:depthScale(localY)
  local centerX, centerY = proj:projectTerrain(wx + runW * 0.5,
                                               wy + CELL * 0.5, height)
  local screenW = runW * depth * proj.scale * (widthScale or 1)
  local screenH = CELL * proj.compression * proj.scale * (heightScale or 1)
  love.graphics.setColor(1, 1, 1, alpha or 1)
  love.graphics.draw(host.source, host.cellQuad,
                     centerX - screenW * 0.5,
                     centerY - screenH * 0.5,
                     0, screenW / runW, screenH / CELL)
  return true
end

local function drawTopRun(host, proj, wx, wy, cells, height)
  if drawTexturedRun(host, proj, wx, wy, cells, height, 1, 1, 1) then
    return true
  end
  local any = false
  for i = 0, cells - 1 do
    any = drawTopCell(host, proj, wx + i * CELL, wy, height) or any
  end
  return any
end

local function drawMassContactShadow(proj, run)
  local alpha, reach = shadowAlpha(run.material)
  local driftX = CELL * 0.07
  local y0 = run.wy + 0.05
  local y1 = run.wy + CELL * reach
  local x0 = run.wx0 + driftX
  local x1 = run.wx1 + driftX + CELL * reach * 0.12
  local ax, ay = proj:projectTerrain(x0, y0, 0.02)
  local bx, by = proj:projectTerrain(x1, y0, 0.02)
  local cx, cy = proj:projectTerrain(x1, y1, 0.02)
  local dx, dy = proj:projectTerrain(x0, y1, 0.02)
  love.graphics.setColor(0, 0, 0, alpha)
  love.graphics.polygon("fill", ax, ay, bx, by, cx, cy, dx, dy)
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

local function drawDoorway(host, ctx, proj, map, cx, cy, ox, oy, height)
  local centerX = (cx + 0.5) * CELL + (ox or 0)
  local wallY = (cy + 1) * CELL + (oy or 0)
  local halfW = CELL * 0.30
  local doorH = math.max(2.5, height * 0.72)
  local left, right = centerX - halfW, centerX + halfW
  local r, g, b, a = host:paletteWallColor(ctx, map, 0.96, 0.30)
  local ax, ay = proj:projectTerrain(left, wallY + 0.02, 0)
  local bx, by = proj:projectTerrain(right, wallY + 0.02, 0)
  local tax, tay = proj:projectTerrain(left, wallY + 0.02, doorH)
  local tbx, tby = proj:projectTerrain(right, wallY + 0.02, doorH)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", tax, tay, tbx, tby, bx, by, ax, ay)

  local lr, lg, lb, la = host:paletteWallColor(ctx, map, 0.92, 0.88)
  local lintel = math.max(0.45, proj.scale > 1 and 0.55 or 0.75)
  local ltax, ltay = proj:projectTerrain(left, wallY + 0.03, doorH)
  local ltbx, ltby = proj:projectTerrain(right, wallY + 0.03, doorH)
  local lbax, lbay = proj:projectTerrain(left, wallY + 0.03, doorH - lintel)
  local lbbx, lbby = proj:projectTerrain(right, wallY + 0.03, doorH - lintel)
  love.graphics.setColor(lr, lg, lb, la)
  love.graphics.polygon("fill", ltax, ltay, ltbx, ltby, lbbx, lbby, lbax, lbay)
end

local function drawStructureEave(host, ctx, proj, map, run)
  local overhang = CELL * 0.10
  local thickness = math.max(0.85, proj.relief * 0.13)
  local wx0 = run.wx0 - overhang
  local wx1 = run.wx1 + overhang
  local wy = run.wy + CELL * 0.025
  local z0 = math.max(0, run.height - thickness * 0.30)
  local z1 = run.height + thickness

  local r, g, b, a = host:paletteWallColor(ctx, map, 0.94, 0.43)
  local ax, ay = proj:projectTerrain(wx0, wy, z0)
  local bx, by = proj:projectTerrain(wx1, wy, z0)
  local tax, tay = proj:projectTerrain(wx0, wy, z1)
  local tbx, tby = proj:projectTerrain(wx1, wy, z1)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", tax, tay, tbx, tby, bx, by, ax, ay)

  local cells = math.max(1, math.floor((run.wx1 - run.wx0) / CELL + 0.5))
  drawTexturedRun(host, proj, run.wx0, run.sourceY, cells,
                  z1 + thickness * 0.18, 1.07, 0.24, 0.96)
end

local function drawGabledRoof(host, ctx, proj, map, mass, ox, oy, height)
  if not mass or (mass.density or 0) < 0.62
     or (mass.spanX or 0) < 2 or (mass.spanY or 0) < 1 then
    return false
  end

  local overhang = CELL * 0.07
  local x0 = mass.minX * CELL + (ox or 0) - overhang
  local x1 = (mass.maxX + 1) * CELL + (ox or 0) + overhang
  local y0 = mass.minY * CELL + (oy or 0) - overhang * 0.35
  local y1 = (mass.maxY + 1) * CELL + (oy or 0) + overhang * 0.55
  local ridgeX = (x0 + x1) * 0.5
  local baseZ = height + math.max(0.75, proj.relief * 0.11)
  local ridgeZ = baseZ + math.max(2.5, proj.relief * 0.52)

  local wx0, wy0 = proj:projectTerrain(x0, y0, baseZ)
  local wx1, wy1 = proj:projectTerrain(x0, y1, baseZ)
  local rx0, ry0 = proj:projectTerrain(ridgeX, y0, ridgeZ)
  local rx1, ry1 = proj:projectTerrain(ridgeX, y1, ridgeZ)
  local ex0, ey0 = proj:projectTerrain(x1, y0, baseZ)
  local ex1, ey1 = proj:projectTerrain(x1, y1, baseZ)

  local r1, g1, b1, a1 = paletteTone(host, ctx, map, 1, 0.94, 0.90)
  love.graphics.setColor(r1, g1, b1, a1)
  love.graphics.polygon("fill", wx0, wy0, wx1, wy1, rx1, ry1, rx0, ry0)

  local r2, g2, b2, a2 = paletteTone(host, ctx, map, 1, 0.79, 0.92)
  love.graphics.setColor(r2, g2, b2, a2)
  love.graphics.polygon("fill", rx0, ry0, rx1, ry1, ex1, ey1, ex0, ey0)

  local rg, gg, bg, ag = host:paletteWallColor(ctx, map, 0.94, 0.62)
  love.graphics.setColor(rg, gg, bg, ag)
  love.graphics.polygon("fill", wx1, wy1, ex1, ey1, rx1, ry1)
  return true
end

local function drawVegetationCrown(host, ctx, proj, map, run)
  local overhang = CELL * 0.16
  local crown = math.max(2.3, proj.relief * 0.34)
  local wx0 = run.wx0 - overhang
  local wx1 = run.wx1 + overhang
  local wy = run.wy + CELL * 0.035
  local z0 = run.height * 0.73
  local z1 = run.height + crown * 0.56

  local r, g, b, a = host:paletteWallColor(ctx, map, 0.88, 0.48)
  local ax, ay = proj:projectTerrain(wx0, wy, z0)
  local bx, by = proj:projectTerrain(wx1, wy, z0)
  local tax, tay = proj:projectTerrain(wx0, wy, z1)
  local tbx, tby = proj:projectTerrain(wx1, wy, z1)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", tax, tay, tbx, tby, bx, by, ax, ay)

  local cells = math.max(1, math.floor((run.wx1 - run.wx0) / CELL + 0.5))
  drawTexturedRun(host, proj, run.wx0, run.sourceY, cells,
                  run.height + crown * 0.62, 1.10, 0.72, 0.97)
  drawTexturedRun(host, proj, run.wx0, run.sourceY, cells,
                  run.height + crown, 1.02, 0.47, 0.92)
end

function Relief:drawRow(host, ctx, proj, map, ox, oy, cy, x0, x1)
  if not (host and host.source and host.cellQuad and map) then return 0 end
  ox, oy = ox or 0, oy or 0
  local classifier = self.MaterialClassifier
  local lift = proj.relief
  local drawn = 0
  local materials = {}
  local frontRuns = {}

  for cx = x0, x1 do
    local material = classifier.classify(map, cx, cy)
    materials[cx] = material
    if material.kind == "solid" then drawn = drawn + 1 end
  end

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
      local run = {
        material = material,
        startX = runStart,
        endX = runEnd,
        wx0 = runStart * CELL + ox,
        wx1 = (runEnd + 1) * CELL + ox,
        sourceY = cy * CELL + oy,
        wy = wy,
        height = height,
      }
      drawMassContactShadow(proj, run)
      self.lastMassShadows = self.lastMassShadows + 1
      drawFrontRun(host, ctx, proj, map, material,
                   run.wx0, run.wx1, wy, height)
      frontRuns[#frontRuns + 1] = run
      self.lastFrontRuns = self.lastFrontRuns + 1
      cx = runEnd + 1
    else
      cx = cx + 1
    end
  end

  for dx = x0, x1 do
    local material = materials[dx]
    if material and material.family == "structure"
       and classifier.frontExposed(map, dx, cy)
       and classifier.isTraversalThreshold(map, dx, cy + 1) then
      local height = classifier.reliefHeight(material, lift)
      drawDoorway(host, ctx, proj, map, dx, cy, ox, oy, height)
      self.lastDoorways = self.lastDoorways + 1
    end
  end

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

  local roofsDrawn = {}
  for _, run in ipairs(frontRuns) do
    local family = run.material.family
    if family == "structure" then
      drawStructureEave(host, ctx, proj, map, run)
      self.lastEaves = self.lastEaves + 1
      local mass = classifier.massInfo(map, run.startX, cy)
      if mass and mass.maxY == cy and not roofsDrawn[mass.id] then
        if drawGabledRoof(host, ctx, proj, map, mass, ox, oy, run.height) then
          self.lastRoofs = self.lastRoofs + 1
        end
        roofsDrawn[mass.id] = true
      end
    elseif family == "vegetation" then
      drawVegetationCrown(host, ctx, proj, map, run)
      self.lastCanopies = self.lastCanopies + 1
    end
  end

  self.lastCells = self.lastCells + drawn
  love.graphics.setColor(1, 1, 1, 1)
  return drawn
end

function Relief:drawScene(host, ctx, proj, map, ox, oy)
  if not (host and host.source and host.cellQuad and map) then return 0 end
  if not (map.widthCells and map.heightCells) then return 0 end

  ox, oy = ox or 0, oy or 0
  local x0, y0, x1, y1 = visibleCellRange(map, proj, ox, oy)
  if x1 < x0 or y1 < y0 then return 0 end
  self.lastScenes = self.lastScenes + 1

  local before = self.lastCells
  for cy = y0, y1 do
    self:drawRow(host, ctx, proj, map, ox, oy, cy, x0, x1)
  end
  return self.lastCells - before
end

function Relief:draw(host, ctx, proj)
  local state = ctx and ctx.state
  local map = state and state.map
  if not map then return 0 end

  self:resetMetrics()
  self:drawScene(host, ctx, proj, map, 0, 0)
  for _, nb in ipairs(state.neighbors or {}) do
    if nb.map then
      self:drawScene(host, ctx, proj, nb.map, nb.ox or 0, nb.oy or 0)
    end
  end
  return self.lastCells
end

return Relief
