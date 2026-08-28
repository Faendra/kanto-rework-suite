local VanillaMotifs = require("hd2d.VanillaMotifs")
local LedgeTopology = require("hd2d.LedgeTopology")

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

-- Outdoor semantic categories remain chromatic, not geometric. The only
-- inferred Gen-I topography is now a verified one-way ledge relation: the
-- standing side is one logical level above its landing side. This directly
-- mirrors the vanilla ledge hop table instead of inventing lawn/path walls.
local function elevationFor(map, cx, cy, level, classifier, material)
  if not map or not OUTDOOR[mapTileset(map)] then return 0, "neutral", "flat" end
  material = material or classifier.classify(map, cx, cy)

  local explicit = explicitElevation(map, cx, cy)
  if explicit ~= nil then
    return clamp(explicit, -1.5, 1.5), "explicit", "explicit"
  end

  local ledgeZ = LedgeTopology.worldZ(map, cx, cy)
  if material.kind == "water" then
    return ledgeZ - 0.085, "water", ledgeZ ~= 0 and "ledge" or "flat"
  end

  local surface = material.surface
      or VanillaMotifs.surfaceKind(map, cx, cy, material)
  if surface ~= "lawn" and surface ~= "path" then surface = "neutral" end
  if material.kind == "solid" and material.family == "structure" then
    surface = "path"
  end
  return ledgeZ, surface, ledgeZ ~= 0 and "ledge" or "flat"
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

local function structureCell(cmd)
  if not (cmd and cmd.scene and cmd.scene.map and cmd.mass) then return nil end
  local mass = cmd.mass
  local cx = math.floor(((mass.minX or 0) + (mass.maxX or mass.minX or 0)) * 0.5 + 0.5)
  local cy = mass.maxY or mass.minY or 0
  return cx, cy, cmd.scene.map
end

local function facePoints(proj, x, y, face)
  local z0, z1 = face.lowerZ, face.upperZ
  if face.dir == "down" then
    local ax, ay = proj:cell(x, y + 1, z0)
    local bx, by = proj:cell(x + 1, y + 1, z0)
    local cx, cy = proj:cell(x + 1, y + 1, z1)
    local dx, dy = proj:cell(x, y + 1, z1)
    return { ax, ay, bx, by, cx, cy, dx, dy }
  elseif face.dir == "up" then
    local ax, ay = proj:cell(x + 1, y, z0)
    local bx, by = proj:cell(x, y, z0)
    local cx, cy = proj:cell(x, y, z1)
    local dx, dy = proj:cell(x + 1, y, z1)
    return { ax, ay, bx, by, cx, cy, dx, dy }
  elseif face.dir == "left" then
    local ax, ay = proj:cell(x, y + 1, z0)
    local bx, by = proj:cell(x, y, z0)
    local cx, cy = proj:cell(x, y, z1)
    local dx, dy = proj:cell(x, y + 1, z1)
    return { ax, ay, bx, by, cx, cy, dx, dy }
  else -- right
    local ax, ay = proj:cell(x + 1, y, z0)
    local bx, by = proj:cell(x + 1, y + 1, z0)
    local cx, cy = proj:cell(x + 1, y + 1, z1)
    local dx, dy = proj:cell(x + 1, y, z1)
    return { ax, ay, bx, by, cx, cy, dx, dy }
  end
end

local function drawLedgeFace(renderer, proj, x, y, face)
  if not face or not love or not love.graphics then return false end
  local p = facePoints(proj, x, y, face)
  local texture = face.atlasTexture
  if texture and renderer.mesh and renderer.mesh.setVertices and renderer.mesh.setTexture then
    local vertices = {
      { p[1], p[2], 0, 1, 1, 1, 1, 1 },
      { p[3], p[4], 1, 1, 1, 1, 1, 1 },
      { p[5], p[6], 1, 0, 1, 1, 1, 1 },
      { p[7], p[8], 0, 0, 1, 1, 1, 1 },
    }
    local ok = pcall(function()
      renderer.mesh:setVertices(vertices)
      renderer.mesh:setTexture(texture)
    end)
    if ok then
      love.graphics.setColor(0.82, 0.82, 0.78, 1)
      love.graphics.draw(renderer.mesh)
      return true
    end
  end

  -- Compatibility fallback only. Real atlas-direct LÖVE uses the exact ledge
  -- pixels; this warm earth tone avoids ever reintroducing TEST8/9's grey wall.
  love.graphics.setColor(0.34, 0.28, 0.18, 1)
  love.graphics.polygon("fill", p)
  return false
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
    self.lastLedgeLevelCells = 0
    self.lastLedgeFaces = 0
    self.lastTexturedLedgeFaces = 0
    self._terrainElevation = {}
    self._terrainStyle = {}
    self._terrainLedgeFaces = {}
  end

  local baseInvalidate = renderer.invalidate
  renderer.invalidate = function(self)
    LedgeTopology.invalidate()
    return baseInvalidate(self)
  end

  local baseBuildScene = renderer.buildScene
  renderer.buildScene = function(self, ctx, proj)
    local ground, objects, scenes = baseBuildScene(self, ctx, proj)
    self._terrainElevation = {}
    self._terrainStyle = {}
    self._terrainLedgeFaces = {}

    for _, cmd in ipairs(ground or {}) do
      local map = cmd.scene and cmd.scene.map
      local elev, style, elevKind = elevationFor(map,
                                       cmd.cx or 0, cmd.cy or 0,
                                       proj.level, self.MaterialClassifier,
                                       cmd.material)
      cmd.z = elev
      local k = key(cmd.x, cmd.y)
      self._terrainElevation[k] = elev
      self._terrainStyle[k] = style
      if style == "path" then self.lastPathCells = self.lastPathCells + 1 end
      if elevKind == "explicit" then
        self.lastExplicitElevationCells = self.lastExplicitElevationCells + 1
      elseif elevKind == "ledge" then
        self.lastLedgeLevelCells = self.lastLedgeLevelCells + 1
      elseif style ~= "water" then
        self.lastFlatOutdoorCells = self.lastFlatOutdoorCells + 1
      end

      if map and cmd.cx ~= nil and cmd.cy ~= nil then
        local face = LedgeTopology.faceAt(map, cmd.cx, cmd.cy)
        if face then
          if self.atlasSource and self.atlasSource.cellTexture then
            face.atlasTexture = self.atlasSource.cellTexture(self, map, cmd.cx, cmd.cy)
          end
          self._terrainLedgeFaces[k] = face
        end
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

    local ok = baseDrawTexturedQuad(self, proj, x, y, z, rect, fallback)
    if isGround then
      local r, g, b, a = overlayColor(style)
      if r then
        love.graphics.setColor(r, g, b, a)
        love.graphics.polygon("fill", proj:cellPolygon(x, y, (z or 0) + 0.0015))
      end
      local face = self._terrainLedgeFaces and self._terrainLedgeFaces[k]
      if face then
        self.lastLedgeFaces = self.lastLedgeFaces + 1
        if drawLedgeFace(self, proj, x, y, face) then
          self.lastTexturedLedgeFaces = self.lastTexturedLedgeFaces + 1
        end
      end
    end
    return ok
  end

  local baseDrawActor = renderer.drawActor
  renderer.drawActor = function(self, proj, row)
    local cx, cy, map = rowLocalCell(row)
    if not map then return baseDrawActor(self, proj, row) end
    local material = self.MaterialClassifier.classify(map, cx, cy)
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

  local baseDrawStructure = renderer.drawStructure
  renderer.drawStructure = function(self, proj, cmd)
    local cx, cy, map = structureCell(cmd)
    if not map then return baseDrawStructure(self, proj, cmd) end
    local material = self.MaterialClassifier.classify(map, cx, cy)
    local elev = elevationFor(map, cx, cy, proj.level,
                              self.MaterialClassifier, material)
    return baseDrawStructure(self, proxyProjection(proj, elev), cmd)
  end

  local baseSurfaceZForWorld = renderer.surfaceZForWorld
  renderer.surfaceZForWorld = function(self, scenes, wx, wy)
    local base = baseSurfaceZForWorld(self, scenes, wx, wy)
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
TerrainRemaster.drawLedgeFace = drawLedgeFace

return TerrainRemaster
