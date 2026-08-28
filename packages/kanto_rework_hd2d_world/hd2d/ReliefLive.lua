local Relief = {}
Relief.__index = Relief

local CELL = 16
local MARGIN_CELLS = 2
local GROUND_DONORS = {
  { 0, 1 }, { -1, 0 }, { 1, 0 }, { 0, -1 },
  { -1, 1 }, { 1, 1 }, { -2, 0 }, { 2, 0 }, { 0, 2 }, { 0, -2 },
}

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
  if r > 1 or g > 1 or b > 1 then
    r, g, b = r / 255, g / 255, b / 255
  end
  return r, g, b
end

local function paletteTone(host, ctx, map, fromDark, factor, alpha)
  local fallback = { 0.30, 0.34, 0.30 }
  local palette = ctx.paletteFor and ctx.paletteFor(map) or nil
  if type(palette) ~= "table" or #palette == 0 then
    local r, g, b, a = host:paletteWallColor(ctx, map, alpha or 1, factor or 1)
    -- Never let a fallback semantic face collapse to pure black. The live
    -- capture exposed that as long rectangular voids under rocks/trees.
    return math.max(r, 0.12), math.max(g, 0.13), math.max(b, 0.12), a
  end
  local index = clamp(#palette - (fromDark or 1), 1, #palette)
  local r, g, b = normalizeColor(palette[index], fallback)
  factor = factor or 1
  return clamp(r * factor, 0.08, 1),
         clamp(g * factor, 0.09, 1),
         clamp(b * factor, 0.08, 1),
         alpha or 1
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
    lastGroundMasks = 0,
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
  self.lastMassShadows, self.lastRoofs, self.lastGroundMasks = 0, 0, 0
end

local function sameMass(a, b)
  if not (a and b and a.kind == "solid" and b.kind == "solid") then return false end
  if a.massId ~= nil or b.massId ~= nil then return a.massId == b.massId end
  return a.family == b.family
end

local function geometryHeight(classifier, material, lift)
  local raw = classifier.reliefHeight(material, lift)
  local family = material and material.family or "mass"
  if family == "structure" then return raw * 0.78 end
  if family == "vegetation" then return math.max(0.9, raw * 0.08) end
  if family == "boundary" then return math.max(0.8, raw * 0.10) end
  if family == "obstacle" then return math.max(1.2, raw * 0.38) end
  if family == "landmark" then return math.max(1.4, raw * 0.28) end
  return math.max(1.1, raw * 0.22)
end

local function groundDonor(classifier, map, cx, cy)
  local grassCandidate
  for _, d in ipairs(GROUND_DONORS) do
    local nx, ny = cx + d[1], cy + d[2]
    local material = classifier.classify(map, nx, ny)
    if material.kind == "ground" then return nx, ny end
    if not grassCandidate and material.kind == "grass" then
      grassCandidate = { nx, ny }
    end
  end
  if grassCandidate then return grassCandidate[1], grassCandidate[2] end
  return nil
end

-- Only architecture needs its original flat footprint removed. Natural masses
-- keep the original Gen I ground art beneath them so a failed donor lookup can
-- never turn a map edge into a bright/black rectangle.
local function drawStructureGroundReplacement(host, proj, map, classifier, cx, cy, ox, oy)
  local donorX, donorY = groundDonor(classifier, map, cx, cy)
  if not donorX then return false end
  local sourceX = donorX * CELL + ox - proj.camX
  local sourceY = donorY * CELL + oy - proj.bgY
  if sourceX < 0 or sourceY < 0
     or sourceX + CELL > host.sourceW or sourceY + CELL > host.sourceH then
    return false
  end

  host.cellQuad:setViewport(sourceX, sourceY, CELL, CELL,
                            host.sourceW, host.sourceH)
  local metrics = proj:cellMetrics(cx * CELL + ox, cy * CELL + oy, CELL, 0)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(host.source, host.cellQuad, metrics.x, metrics.y,
                     0, metrics.width / CELL, metrics.height / CELL)
  return true
end

local function sourceRunVisible(host, proj, wx0, sourceY, cells)
  local runW = cells * CELL
  local sx = wx0 - proj.camX
  local sy = sourceY - proj.bgY
  if sx < 0 or sy < 0 or sx + runW > host.sourceW or sy + CELL > host.sourceH then
    return nil
  end
  return sx, sy, runW
end

local function drawProjectedTopRun(host, proj, wx0, sourceY, cells, z, alpha)
  local sx, sy, runW = sourceRunVisible(host, proj, wx0, sourceY, cells)
  if not sx then return false end
  host.cellQuad:setViewport(sx, sy, runW, CELL, host.sourceW, host.sourceH)
  local localY = sourceY - proj.bgY + CELL * 0.5
  local depth = proj:depthScale(localY)
  local centerX, centerY = proj:projectTerrain(wx0 + runW * 0.5,
                                               sourceY + CELL * 0.5, z)
  local screenW = runW * depth * proj.scale
  local screenH = CELL * proj.compression * proj.scale
  love.graphics.setColor(1, 1, 1, alpha or 1)
  love.graphics.draw(host.source, host.cellQuad,
                     centerX - screenW * 0.5,
                     centerY - screenH * 0.5,
                     0, screenW / runW, screenH / CELL)
  return true
end

local function drawUprightRun(host, proj, wx0, sourceY, cells,
                              baselineY, screenHeightWorld, widthScale, alpha)
  local sx, sy, runW = sourceRunVisible(host, proj, wx0, sourceY, cells)
  if not sx then return false end
  host.cellQuad:setViewport(sx, sy, runW, CELL, host.sourceW, host.sourceH)
  local depth = proj:depthScale(baselineY - proj.bgY)
  local centerX, groundY = proj:projectTerrain(wx0 + runW * 0.5, baselineY, 0)
  local screenW = runW * depth * proj.scale * (widthScale or 1)
  local screenH = math.max(1, screenHeightWorld * proj.scale)
  love.graphics.setColor(1, 1, 1, alpha or 1)
  love.graphics.draw(host.source, host.cellQuad,
                     centerX - screenW * 0.5,
                     groundY - screenH,
                     0, screenW / runW, screenH / CELL)
  return true
end

local function drawContactShadow(proj, run, family)
  local alpha = family == "structure" and 0.12 or 0.065
  local reach = family == "structure" and 0.22 or 0.12
  local x0 = run.wx0 + CELL * 0.04
  local x1 = run.wx1 + CELL * 0.08
  local y0 = run.wy + 0.02
  local y1 = run.wy + CELL * reach
  local ax, ay = proj:projectTerrain(x0, y0, 0.01)
  local bx, by = proj:projectTerrain(x1, y0, 0.01)
  local cx, cy = proj:projectTerrain(x1, y1, 0.01)
  local dx, dy = proj:projectTerrain(x0, y1, 0.01)
  love.graphics.setColor(0, 0, 0, alpha)
  love.graphics.polygon("fill", ax, ay, bx, by, cx, cy, dx, dy)
end

local function drawFaceQuad(host, ctx, proj, map, material, wx0, wx1, wy, height)
  local family = material.family or "mass"
  local fromDark, factor = 2, 0.82
  if family == "structure" then fromDark, factor = 2, 0.95
  elseif family == "landmark" then fromDark, factor = 2, 0.78
  elseif family == "obstacle" then fromDark, factor = 2, 0.74
  end
  local r, g, b, a = paletteTone(host, ctx, map, fromDark, factor, 1)
  local ax, ay = proj:projectTerrain(wx0, wy, 0)
  local bx, by = proj:projectTerrain(wx1, wy, 0)
  local tx0, ty0 = proj:projectTerrain(wx0, wy, height)
  local tx1, ty1 = proj:projectTerrain(wx1, wy, height)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", tx0, ty0, tx1, ty1, bx, by, ax, ay)
end

local function drawStructureSide(host, ctx, proj, map, wx, wy, height)
  local r, g, b, a = paletteTone(host, ctx, map, 1, 0.66, 1)
  local ax, ay = proj:projectTerrain(wx + CELL, wy, 0)
  local bx, by = proj:projectTerrain(wx + CELL, wy + CELL, 0)
  local tx0, ty0 = proj:projectTerrain(wx + CELL, wy, height)
  local tx1, ty1 = proj:projectTerrain(wx + CELL, wy + CELL, height)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", tx0, ty0, tx1, ty1, bx, by, ax, ay)
end

local function drawDoorway(host, ctx, proj, map, cx, cy, ox, oy, height)
  local centerX = (cx + 0.5) * CELL + (ox or 0)
  local wallY = (cy + 1) * CELL + (oy or 0)
  local halfW = CELL * 0.27
  local doorH = math.max(2.4, height * 0.68)
  local r, g, b, a = paletteTone(host, ctx, map, 1, 0.48, 1)
  local ax, ay = proj:projectTerrain(centerX - halfW, wallY + 0.02, 0)
  local bx, by = proj:projectTerrain(centerX + halfW, wallY + 0.02, 0)
  local tx0, ty0 = proj:projectTerrain(centerX - halfW, wallY + 0.02, doorH)
  local tx1, ty1 = proj:projectTerrain(centerX + halfW, wallY + 0.02, doorH)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", tx0, ty0, tx1, ty1, bx, by, ax, ay)
end

local function drawEave(host, ctx, proj, map, run)
  local thickness = math.max(0.45, proj.relief * 0.08)
  local z = run.height + thickness
  local r, g, b, a = paletteTone(host, ctx, map, 1, 0.58, 1)
  local ax, ay = proj:projectTerrain(run.wx0 - CELL * 0.06, run.wy, z)
  local bx, by = proj:projectTerrain(run.wx1 + CELL * 0.06, run.wy, z)
  local cx, cy = proj:projectTerrain(run.wx1 + CELL * 0.06, run.wy, z - thickness)
  local dx, dy = proj:projectTerrain(run.wx0 - CELL * 0.06, run.wy, z - thickness)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", ax, ay, bx, by, cx, cy, dx, dy)
end

-- The first live build spanned the roof across the full collision component,
-- making houses read as huge blue slabs. This cap uses only the front-most
-- 1.25 cells of structural depth: enough to read as a pitched roof without
-- turning the whole building footprint into one giant plane.
local function drawRoof(host, ctx, proj, map, mass, ox, oy, height)
  if not mass or (mass.spanX or 0) < 2 then return false end
  local overhang = CELL * 0.055
  local x0 = mass.minX * CELL + (ox or 0) - overhang
  local x1 = (mass.maxX + 1) * CELL + (ox or 0) + overhang
  local yFront = (mass.maxY + 1) * CELL + (oy or 0) + overhang * 0.30
  local depthWorld = math.min((mass.spanY or 1) * CELL * 0.48, CELL * 1.25)
  local yBack = yFront - depthWorld
  local ridgeX = (x0 + x1) * 0.5
  local baseZ = height + math.max(0.45, proj.relief * 0.07)
  local ridgeZ = baseZ + math.max(1.8, proj.relief * 0.24)

  local ax0, ay0 = proj:projectTerrain(x0, yBack, baseZ)
  local ax1, ay1 = proj:projectTerrain(x0, yFront, baseZ)
  local rx0, ry0 = proj:projectTerrain(ridgeX, yBack, ridgeZ)
  local rx1, ry1 = proj:projectTerrain(ridgeX, yFront, ridgeZ)
  local bx0, by0 = proj:projectTerrain(x1, yBack, baseZ)
  local bx1, by1 = proj:projectTerrain(x1, yFront, baseZ)

  local r1, g1, b1, a1 = paletteTone(host, ctx, map, 2, 1.02, 1)
  love.graphics.setColor(r1, g1, b1, a1)
  love.graphics.polygon("fill", ax0, ay0, ax1, ay1, rx1, ry1, rx0, ry0)

  local r2, g2, b2, a2 = paletteTone(host, ctx, map, 2, 0.88, 1)
  love.graphics.setColor(r2, g2, b2, a2)
  love.graphics.polygon("fill", rx0, ry0, rx1, ry1, bx1, by1, bx0, by0)
  return true
end

local function drawVegetation(host, proj, run)
  local cells = run.endX - run.startX + 1
  -- One upright source-textured layer per exposed mass edge. No opaque vertical
  -- pedestal is emitted, so tree walls cannot become black/green block towers.
  local ok = drawUprightRun(host, proj, run.wx0, run.sourceY, cells,
                            run.wy + 0.03, CELL * 1.03, 1.06, 1)
  if ok then
    local sx, sy, runW = sourceRunVisible(host, proj, run.wx0, run.sourceY, cells)
    if sx then
      host.cellQuad:setViewport(sx, sy, runW, CELL, host.sourceW, host.sourceH)
      local depth = proj:depthScale(run.wy - proj.bgY)
      local centerX, groundY = proj:projectTerrain(run.wx0 + runW * 0.5,
                                                   run.wy + 0.03, 0)
      local screenW = runW * depth * proj.scale * 0.76
      local screenH = CELL * proj.scale * 0.38
      love.graphics.setColor(1, 1, 1, 0.96)
      love.graphics.draw(host.source, host.cellQuad,
                         centerX - screenW * 0.5,
                         groundY - CELL * proj.scale * 1.03 - screenH * 0.30,
                         0, screenW / runW, screenH / CELL)
    end
  end
  return ok
end

local function drawNaturalEdge(host, proj, run)
  local cells = run.endX - run.startX + 1
  -- Rocks/fences/boundaries receive a shallow textured lip instead of a dark
  -- palette wall. This keeps their original pixel identity while adding depth.
  return drawUprightRun(host, proj, run.wx0, run.sourceY, cells,
                        run.wy + 0.02, CELL * 0.24, 1.00, 1)
end

function Relief:drawRow(host, ctx, proj, map, ox, oy, cy, x0, x1)
  if not (host and host.source and host.cellQuad and map) then return 0 end
  ox, oy = ox or 0, oy or 0
  local classifier = self.MaterialClassifier
  local materials = {}
  local drawn = 0

  for cx = x0, x1 do
    local material = classifier.classify(map, cx, cy)
    materials[cx] = material
    if material.kind == "solid" then drawn = drawn + 1 end
  end

  -- Erase only structural flat footprints. Natural boundaries remain in the
  -- base terrain so connected-map seams can never expose replacement blocks.
  for cx = x0, x1 do
    local material = materials[cx]
    if material and material.family == "structure" then
      if drawStructureGroundReplacement(host, proj, map, classifier,
                                        cx, cy, ox, oy) then
        self.lastGroundMasks = self.lastGroundMasks + 1
      end
    end
  end

  local frontRuns = {}
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

      local height = geometryHeight(classifier, material, proj.relief)
      local run = {
        material = material,
        startX = runStart,
        endX = runEnd,
        wx0 = runStart * CELL + ox,
        wx1 = (runEnd + 1) * CELL + ox,
        sourceY = cy * CELL + oy,
        wy = (cy + 1) * CELL + oy,
        height = height,
      }
      local family = material.family or "mass"
      drawContactShadow(proj, run, family)
      self.lastMassShadows = self.lastMassShadows + 1

      if family == "structure" then
        drawFaceQuad(host, ctx, proj, map, material,
                     run.wx0, run.wx1, run.wy, height)
        drawUprightRun(host, proj, run.wx0, run.sourceY,
                       runEnd - runStart + 1, run.wy + 0.01,
                       math.max(3.5, height * 0.72), 1.00, 0.92)
        self.lastFrontRuns = self.lastFrontRuns + 1
      elseif family == "vegetation" then
        if drawVegetation(host, proj, run) then
          self.lastCanopies = self.lastCanopies + 1
        end
        self.lastFrontRuns = self.lastFrontRuns + 1
      elseif family == "boundary" then
        drawNaturalEdge(host, proj, run)
        self.lastFrontRuns = self.lastFrontRuns + 1
      else
        drawFaceQuad(host, ctx, proj, map, material,
                     run.wx0, run.wx1, run.wy, height)
        drawNaturalEdge(host, proj, run)
        self.lastFrontRuns = self.lastFrontRuns + 1
      end

      frontRuns[#frontRuns + 1] = run
      cx = runEnd + 1
    else
      cx = cx + 1
    end
  end

  -- Doors remain tied to real traversal thresholds only.
  for dx = x0, x1 do
    local material = materials[dx]
    if material and material.family == "structure"
       and classifier.frontExposed(map, dx, cy)
       and classifier.isTraversalThreshold(map, dx, cy + 1) then
      drawDoorway(host, ctx, proj, map, dx, cy, ox, oy,
                  geometryHeight(classifier, material, proj.relief))
      self.lastDoorways = self.lastDoorways + 1
    end
  end

  -- High side walls only make sense for architecture. Suppressing sides on
  -- vegetation/boundary masses removes the tall pillars seen at map seams.
  for sx = x0, x1 do
    local material = materials[sx]
    if material and material.family == "structure"
       and classifier.sideExposed(map, sx, cy, 1) then
      drawStructureSide(host, ctx, proj, map,
                        sx * CELL + ox, cy * CELL + oy,
                        geometryHeight(classifier, material, proj.relief))
      self.lastSideFaces = self.lastSideFaces + 1
    end
  end

  -- Only compact obstacles/landmarks retain a raised top copy. Structures use
  -- the coherent roof below; vegetation/boundaries use upright textured edges.
  cx = x0
  while cx <= x1 do
    local material = materials[cx]
    if material and material.kind == "solid" then
      local runStart, runEnd = cx, cx
      while runEnd + 1 <= x1 and sameMass(material, materials[runEnd + 1]) do
        runEnd = runEnd + 1
      end
      local family = material.family or "mass"
      if family ~= "structure" and family ~= "vegetation" and family ~= "boundary" then
        if drawProjectedTopRun(host, proj,
                               runStart * CELL + ox,
                               cy * CELL + oy,
                               runEnd - runStart + 1,
                               geometryHeight(classifier, material, proj.relief), 1) then
          self.lastTopRuns = self.lastTopRuns + 1
        end
      end
      cx = runEnd + 1
    else
      cx = cx + 1
    end
  end

  local roofsDrawn = {}
  for _, run in ipairs(frontRuns) do
    if run.material.family == "structure" then
      drawEave(host, ctx, proj, map, run)
      self.lastEaves = self.lastEaves + 1
      local mass = classifier.massInfo(map, run.startX, cy)
      if mass and mass.maxY == cy and not roofsDrawn[mass.id] then
        if drawRoof(host, ctx, proj, map, mass, ox, oy, run.height) then
          self.lastRoofs = self.lastRoofs + 1
        end
        roofsDrawn[mass.id] = true
      end
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
