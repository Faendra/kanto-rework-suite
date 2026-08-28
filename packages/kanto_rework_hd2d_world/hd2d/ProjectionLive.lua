local Projection = {}
Projection.__index = Projection

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Live-test projection: preserve a clear diorama read without opening large
-- empty bands around the Gen I viewport. Depth grows by mode, but the camera
-- never rotates far enough for map seams or connected-map borders to dominate.
local PRESETS = {
  [1] = { compression = 0.80, near = 1.06, far = 0.94, shear = 0.030, lift = 4.0 },
  [2] = { compression = 0.76, near = 1.10, far = 0.90, shear = 0.045, lift = 5.5 },
  [3] = { compression = 0.72, near = 1.14, far = 0.87, shear = 0.060, lift = 7.0 },
}

function Projection.new(ctx, level)
  local preset = PRESETS[math.max(1, math.min(3, level or 1))] or PRESETS[1]
  local self = setmetatable({}, Projection)
  self.vw = assert(ctx.vw, "projection needs ctx.vw")
  self.vh = assert(ctx.vh, "projection needs ctx.vh")
  self.width = assert(ctx.width, "projection needs ctx.width")
  self.height = assert(ctx.height, "projection needs ctx.height")
  self.scale = tonumber(ctx.scale) or 1
  self.camX = ctx.cam and ctx.cam.x or 0
  self.camY = ctx.cam and ctx.cam.y or 0
  self.bgY = ctx.bgY or self.camY
  self.compression = preset.compression
  self.nearScale = preset.near
  self.farScale = preset.far
  self.shear = preset.shear
  self.relief = preset.lift
  self.centerX = self.width * 0.5
  local projectedH = self.vh * self.compression * self.scale
  -- Bias slightly toward the bottom so the far horizon gets modest breathing
  -- room while the near edge stays inside the actual game canvas.
  self.top = math.floor((self.height - projectedH) * 0.42 + 0.5)
  return self
end

function Projection:depth01(localY)
  return clamp(localY / self.vh, 0, 1)
end

function Projection:depthScale(localY)
  local t = self:depth01(localY)
  return self.farScale + (self.nearScale - self.farScale) * t
end

function Projection:screenY(localY, z)
  return self.top + localY * self.compression * self.scale
         - (z or 0) * self.scale
end

function Projection:screenCenterX(localY)
  return self.centerX + (localY - self.vh * 0.5) * self.shear * self.scale
end

function Projection:projectLocal(localX, localY, z)
  local depth = self:depthScale(localY)
  local sx = self:screenCenterX(localY)
             + (localX - self.vw * 0.5) * depth * self.scale
  local sy = self:screenY(localY, z)
  return sx, sy, depth
end

function Projection:projectWorld(wx, wy, z)
  return self:projectLocal(wx - self.camX, wy - self.camY, z)
end

function Projection:projectTerrain(wx, wy, z)
  return self:projectLocal(wx - self.camX, wy - self.bgY, z)
end

function Projection:stripMetrics(y0, y1)
  local mid = (y0 + y1) * 0.5
  local depth = self:depthScale(mid)
  local xCenter = self:screenCenterX(mid)
  local sy0 = self:screenY(y0, 0)
  local sy1 = self:screenY(y1, 0)
  return xCenter, sy0, sy1, depth
end

function Projection:cellMetrics(wx, wy, size, z)
  size = size or 16
  z = z or 0
  local localY = wy - self.bgY + size * 0.5
  local depth = self:depthScale(localY)
  local sx, sy = self:projectTerrain(wx + size * 0.5, wy + size * 0.5, z)
  return {
    x = sx - size * depth * self.scale * 0.5,
    y = sy - size * self.compression * self.scale * 0.5,
    width = size * depth * self.scale,
    height = size * self.compression * self.scale,
    depth = depth,
    centerX = sx,
    centerY = sy,
  }
end

return Projection
