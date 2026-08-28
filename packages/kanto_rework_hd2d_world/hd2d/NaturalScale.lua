local VanillaMotifs = require("hd2d.VanillaMotifs")

local NaturalScale = {}
local CELL = 16

local function variation(cmd)
  local x = math.floor(tonumber(cmd and cmd.x) or 0)
  local y = math.floor(tonumber(cmd and cmd.y) or 0)
  return ((x * 23 + y * 31) % 7) / 6
end

local function localCell(cmd)
  if not (cmd and cmd.scene and cmd.scene.map) then return nil end
  local ox = (tonumber(cmd.scene.ox) or 0) / CELL
  local oy = (tonumber(cmd.scene.oy) or 0) / CELL
  local cx = math.floor((tonumber(cmd.x) or 0) - ox + 0.001)
  local cy = math.floor((tonumber(cmd.y) or 0) - oy + 0.001)
  return cmd.scene.map, cx, cy
end

local function scaledProjection(proj, scaleFactor)
  if not proj or math.abs((scaleFactor or 1) - 1) < 0.0001 then return proj end
  local proxy = { level = proj.level, tileW = proj.tileW, tileH = proj.tileH,
                  elevation = proj.elevation, spriteScale = proj.spriteScale }
  proxy.cell = function(_, ...) return proj:cell(...) end
  proxy.worldPixel = function(_, ...) return proj:worldPixel(...) end
  proxy.quad = function(_, ...) return proj:quad(...) end
  proxy.cellPolygon = function(_, ...) return proj:cellPolygon(...) end
  proxy.depth = function(_, ...) return proj:depth(...) end
  proxy.visibleRadius = function() return proj:visibleRadius() end
  proxy.spriteScaleAt = function(_, x, y, z)
    local s = proj.spriteScaleAt and proj:spriteScaleAt(x, y, z) or 1
    return s * scaleFactor
  end
  proxy.screenScale = function(_, x, y, z)
    local s = proj.screenScale and proj:screenScale(x, y, z) or proj.tileW or 1
    return s * scaleFactor
  end
  return setmetatable(proxy, { __index = proj })
end

function NaturalScale.apply(renderer)
  if not renderer or renderer.__naturalScaleApplied then return renderer end
  renderer.__naturalScaleApplied = true

  local baseResetMetrics = renderer.resetMetrics
  renderer.resetMetrics = function(self)
    baseResetMetrics(self)
    self.lastScaledTrees = 0
    self.lastFlattenedBoulders = 0
  end

  local baseDrawVegetation = renderer.drawVegetation
  renderer.drawVegetation = function(self, proj, cmd)
    local v = variation(cmd)
    -- TEST8 live capture showed one-cell trees reading as a tall repeated wall.
    -- Keep their exact pixel silhouette but reduce screen height and introduce a
    -- tiny deterministic variation so long borders do not read as cloned posts.
    local factor = 0.70 + v * 0.045
    self.lastScaledTrees = (self.lastScaledTrees or 0) + 1
    return baseDrawVegetation(self, scaledProjection(proj, factor), cmd)
  end

  local baseDrawLowPrism = renderer.drawLowPrism
  renderer.drawLowPrism = function(self, proj, cmd, height, topColor)
    local map, cx, cy = localCell(cmd)
    if map and VanillaMotifs.cellMotif(map, cx, cy) == "boulder" then
      -- The boulder top texture is already correct; only its vertical relief was
      -- excessive. Reduce screen-space rise while preserving the footprint.
      self.lastFlattenedBoulders = (self.lastFlattenedBoulders or 0) + 1
      return baseDrawLowPrism(self, scaledProjection(proj, 0.52),
                              cmd, height, topColor)
    end
    return baseDrawLowPrism(self, proj, cmd, height, topColor)
  end

  return renderer
end

return NaturalScale
