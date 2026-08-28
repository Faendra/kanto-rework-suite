local VanillaMotifs = require("hd2d.VanillaMotifs")

local TerrainRemaster = {}
local CELL = 16

local OUTDOOR = {
  OVERWORLD = true,
  FOREST = true,
  SHIP_PORT = true,
  PLATEAU = true,
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function mapTileset(map)
  return map and map.def and map.def.tileset or nil
end

local function key(x, y)
  return string.format("%.4f:%.4f", tonumber(x) or 0, tonumber(y) or 0)
end

-- TEST8 proved that semantic tile categories are not topography. Raising every
-- lawn cell above every path fabricated long grey retaining walls through
-- Pallet/Route 1. Gen I outdoor terrain is therefore coplanar unless the engine
-- exposes an explicit elevation API. Water remains slightly recessed.
local function explicitElevation(map, cx, cy)
  if not map then return nil end
  for _, name in ipairs({ "elevationAtCell", "heightAtCell", "zAtCell" }) do
    local fn = map[name]
    if type(fn) == "function" then
      local ok, value = pcall(fn, map, cx, cy)
      if ok and type(value) == "number" then return value end
    end
  end
  return nil
end

local function elevationFor(map, cx, cy, level, classifier, material)
  if not map or not OUTDOOR[mapTileset(map)] then return 0, "neutral" end
  material = material or classifier.classify(map, cx, cy)
  if material.kind == "water" then return -0.085, "water" end

  local explicit = explicitElevation(map, cx, cy)
  if explicit ~= nil then
    return clamp(explicit, -1.5, 1.5), "explicit"
  end

  local surface = material.surface
      or VanillaMotifs.surfaceKind(map, cx, cy, material)
  if surface == "lawn" then return 0, "lawn" end
  if surface == "path" then return 0, "path" end
  if material.kind == "solid" and material.family == "structure" then
    return 0, "path"
  end
  return 0, "neutral"
end

local function proxyProjection(proj, baseZ)
  if math.abs(baseZ or 0) < 0.00001 then return proj end
  local proxy = {
    tileW = proj.tileW,
    tileH = proj.tileH,
    elevation = proj.elevation,
    spriteScale = proj.spriteScale,
    level = proj.level,
  }
  proxy.cell = function(_, x, y, z)
    return proj:cell(x, y, (z or 0) + baseZ)
  end
  proxy.worldPixel = function(_, wx, wy, z)
    return proj:worldPixel(wx, wy, (z or 0) + baseZ)
  end
  proxy.quad = function(_, x0, y0, x1, y1, z)
    return proj:quad(x0, y0, x1, y1, (z or 0) + baseZ)
  end
  proxy.cellPolygon = function(_, x, y, z)
    return proj:cellPolygon(x, y, (z or 0) + baseZ)
  end
  proxy.screenScale = function(_, x, y, z)
    return proj:screenScale(x, y, (z or 0) + baseZ)
  end
  proxy.spriteScaleAt = function(_, x, y, z)
    return proj:spriteScaleAt(x, y, (z or 0) + baseZ)
  end
  proxy.depth = function(_, x, y, bias)
    return proj:depth(x, y, bias)
  end
  proxy.visibleRadius = function()
    return proj:visibleRadius()
  end
  return setmetatable(proxy, { __index = proj })
end

local function overlayColor(style)
  -- Surface differentiation is intentionally chromatic only. No semantic
  -- height means no invented cliff between path and lawn.
  if style == "lawn" then return 0.16, 0.34, 0.13, 0.045 end
  if style == "path" then return 0.50, 0.45, 0.34, 0.025 end
  return nil
end

local function cmdLocalCell(cmd)
  if not (cmd and cmd.scene and cmd.scene.map) then return nil end
  local ox = (tonumber(cmd.scene.ox) or 0) / CELL
  local oy = (tonumber(cmd.scene.oy) or 0) / CELL
  return math.floor((tonumber(cmd.x) or 0) - ox + 0.001),
         math.floor((tonumber(cmd.y) or 0) - oy + 0.001),
         cmd.scene.map
end

local function rowLocalCell(row)
  if not (row and row.map) then return nil end
  local cx = math.floor(((row.basePx or row.px or 0) + 8) / CELL)
  local cy = math.floor(((row.basePy or row.py or 0) + 12) / CELL)
  return cx, cy, row.map
end

function TerrainRemaster.apply(renderer)
  if not renderer or renderer.__terrainRemasterApplied then return renderer end
  renderer.__terrainRemasterApplied = true

  local baseResetMetrics = renderer.resetMetrics
  renderer.resetMetrics = function(self)
    baseResetMetrics(self)
    self.lastRaisedLawnCells = 0
    self.lastPathCells = 0
    self.lastTerrainSkirts = 0
    self.lastFlatOutdoorCells = 0
    self.lastExplicitElevationCells = 0
    self._terrainElevation = {}
    self._terrainStyle = {}
  end

  local baseBuildScene = renderer.buildScene
  renderer.buildScene = function(self, ctx, proj)
    local ground, objects, scenes = baseBuildScene(self, ctx, proj)
    self._terrainElevation = {}
    self._terrainStyle = {}

    for _, cmd in ipairs(ground or {}) do
      local elev, style = elevationFor(cmd.scene and cmd.scene.map,
                                       cmd.cx or 0, cmd.cy or 0,
                                       proj.level, self.MaterialClassifier,
                                       cmd.material)
      cmd.z = elev
      local k = key(cmd.x, cmd.y)
      self._terrainElevation[k] = elev
      self._terrainStyle[k] = style
      if style == "path" then self.lastPathCells = self.lastPathCells + 1 end
      if style == "explicit" then
        self.lastExplicitElevationCells = self.lastExplicitElevationCells + 1
      elseif style ~= "water" then
        self.lastFlatOutdoorCells = self.lastFlatOutdoorCells + 1
      end
    end
    return ground, objects, scenes
  end

  local baseDrawTexturedQuad = renderer.drawTexturedQuad
  renderer.drawTexturedQuad = function(self, proj, x, y, z, rect, fallback)
    local k = key(x, y)
    local elev = self._terrainElevation and self._terrainElevation[k]
    local style = self._terrainStyle and self._terrainStyle[k]
    local isGround = elev ~= nil and math.abs((tonumber(z) or 0) - elev) < 0.0005

    -- No semantic terrain skirts. If a future map exposes true elevations, the
    -- height is respected for placement while vertical geology gets its own
    -- explicit renderer rather than a generic grey wall.
    local ok = baseDrawTexturedQuad(self, proj, x, y, z, rect, fallback)
    if isGround then
      local r, g, b, a = overlayColor(style)
      if r then
        love.graphics.setColor(r, g, b, a)
        love.graphics.polygon("fill", proj:cellPolygon(x, y, (z or 0) + 0.0015))
      end
    end
    return ok
  end

  local baseDrawActor = renderer.drawActor
  renderer.drawActor = function(self, proj, row)
    local cx, cy, map = rowLocalCell(row)
    if not map then return baseDrawActor(self, proj, row) end
    local material = self.MaterialClassifier.classify(map, cx, cy)
    if material.kind == "water" then return baseDrawActor(self, proj, row) end
    local elev = elevationFor(map, cx, cy, proj.level,
                              self.MaterialClassifier, material)
    return baseDrawActor(self, proxyProjection(proj, elev), row)
  end

  local baseDrawVegetation = renderer.drawVegetation
  renderer.drawVegetation = function(self, proj, cmd)
    local cx, cy, map = cmdLocalCell(cmd)
    if not map then return baseDrawVegetation(self, proj, cmd) end
    local material = self.MaterialClassifier.classify(map, cx, cy)
    local elev = elevationFor(map, cx, cy, proj.level,
                              self.MaterialClassifier, material)
    return baseDrawVegetation(self, proxyProjection(proj, elev), cmd)
  end

  local baseDrawLowPrism = renderer.drawLowPrism
  renderer.drawLowPrism = function(self, proj, cmd, height, topColor)
    local cx, cy, map = cmdLocalCell(cmd)
    if not map then return baseDrawLowPrism(self, proj, cmd, height, topColor) end
    local material = self.MaterialClassifier.classify(map, cx, cy)
    local elev = elevationFor(map, cx, cy, proj.level,
                              self.MaterialClassifier, material)
    return baseDrawLowPrism(self, proxyProjection(proj, elev), cmd, height, topColor)
  end

  local baseSurfaceZForWorld = renderer.surfaceZForWorld
  renderer.surfaceZForWorld = function(self, scenes, wx, wy)
    local base = baseSurfaceZForWorld(self, scenes, wx, wy)
    if base < -0.001 then return base end
    local scene, lx, ly = self:sceneForWorldPixel(scenes, wx, wy)
    if not scene then return base end
    local cx, cy = math.floor(lx / CELL), math.floor(ly / CELL)
    local material = self.MaterialClassifier.classify(scene.map, cx, cy)
    local elev = elevationFor(scene.map, cx, cy, math.max(1, self.level),
                              self.MaterialClassifier, material)
    return elev
  end

  return renderer
end

TerrainRemaster.elevationFor = elevationFor
TerrainRemaster.proxyProjection = proxyProjection

return TerrainRemaster
