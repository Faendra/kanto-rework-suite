local LedgeTopology = require("hd2d.LedgeTopology")

local LedgeHopSmoothing = {}
local CELL = 16

local function proxyProjection(proj, deltaZ)
  if math.abs(deltaZ or 0) < 0.00001 then return proj end
  local proxy = {
    tileW = proj.tileW,
    tileH = proj.tileH,
    elevation = proj.elevation,
    spriteScale = proj.spriteScale,
    level = proj.level,
  }
  proxy.cell = function(_, x, y, z)
    return proj:cell(x, y, (z or 0) + deltaZ)
  end
  proxy.worldPixel = function(_, wx, wy, z)
    return proj:worldPixel(wx, wy, (z or 0) + deltaZ)
  end
  proxy.quad = function(_, x0, y0, x1, y1, z)
    return proj:quad(x0, y0, x1, y1, (z or 0) + deltaZ)
  end
  proxy.cellPolygon = function(_, x, y, z)
    return proj:cellPolygon(x, y, (z or 0) + deltaZ)
  end
  proxy.screenScale = function(_, x, y, z)
    return proj:screenScale(x, y, (z or 0) + deltaZ)
  end
  proxy.spriteScaleAt = function(_, x, y, z)
    return proj:spriteScaleAt(x, y, (z or 0) + deltaZ)
  end
  proxy.depth = function(_, x, y, bias)
    return proj:depth(x, y, bias)
  end
  proxy.visibleRadius = function()
    return proj:visibleRadius()
  end
  return setmetatable(proxy, { __index = proj })
end

local function rowCell(row)
  if not (row and row.map) then return nil end
  local cx = math.floor(((row.basePx or row.px or 0) + 8) / CELL)
  local cy = math.floor(((row.basePy or row.py or 0) + 12) / CELL)
  return cx, cy
end

function LedgeHopSmoothing.apply(renderer)
  if not renderer or renderer.__ledgeHopSmoothingApplied then return renderer end
  renderer.__ledgeHopSmoothingApplied = true

  local baseResetMetrics = renderer.resetMetrics
  renderer.resetMetrics = function(self)
    baseResetMetrics(self)
    self.lastSmoothedLedgeActors = 0
  end

  -- TerrainRemaster is already installed when this wrapper runs. It will add
  -- the static terrain Z for the actor's current cell. We therefore pre-offset
  -- the projection by (smoothHopZ - staticCellZ), so the nested projections
  -- resolve to exactly smoothHopZ. Player:pose() keeps supplying the vanilla
  -- sine arc on top through row.py/basePy; this layer never reimplements it.
  local baseDrawActor = renderer.drawActor
  renderer.drawActor = function(self, proj, row)
    if row and row.hopping and row.actor and row.map then
      local hopZ = LedgeTopology.hopWorldZ(row.map, row.actor)
      if hopZ ~= nil then
        local cx, cy = rowCell(row)
        if cx ~= nil then
          local staticZ = LedgeTopology.worldZ(row.map, cx, cy)
          self.lastSmoothedLedgeActors = (self.lastSmoothedLedgeActors or 0) + 1
          return baseDrawActor(self, proxyProjection(proj, hopZ - staticZ), row)
        end
      end
    end
    return baseDrawActor(self, proj, row)
  end

  return renderer
end

LedgeHopSmoothing.proxyProjection = proxyProjection

return LedgeHopSmoothing
