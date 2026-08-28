local Projection = {}
Projection.__index = Projection

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local PRESETS = {
  -- Deliberately restrained: the world should read as a spatial remake of
  -- Kanto, not as a stack of cubes. Higher modes increase depth separation,
  -- not camera rotation.
  [1] = { compression = 0.72, near = 1.08, far = 0.91, shear = 0.045, lift = 5 },
  [2] = { compression = 0.66, near = 1.13, far = 0.86, shear = 0.070, lift = 7 },
  [3] = { compression = 0.61, near = 1.18, far = 0.82, shear = 0.090, lift = 9 },
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
  self.top = math.floor((self.height - projectedH) * 0.48 + 0.5)
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
  -- Terrain is rendered against bgY so elevator shake remains a BG-only
  -- motion, matching the engine's flat path.
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
