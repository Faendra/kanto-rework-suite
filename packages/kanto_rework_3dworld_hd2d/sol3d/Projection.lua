local Projection = {}
Projection.__index = Projection

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function Projection.new(width, height, level, playerX, playerY)
  level = math.max(1, math.min(3, math.floor(tonumber(level) or 1)))

  local base = clamp(math.min(width / 24, height / 14), 24, 54)
  local tileW = base * ({ 0.92, 1.00, 1.08 })[level]
  local tileH = tileW * ({ 0.40, 0.46, 0.52 })[level]
  local elevation = tileH * ({ 1.00, 1.35, 1.65 })[level]

  return setmetatable({
    width = width,
    height = height,
    level = level,
    tileW = tileW,
    tileH = tileH,
    elevation = elevation,
    centerX = width * 0.50,
    centerY = height * ({ 0.54, 0.56, 0.59 })[level],
    cameraX = (playerX or 0) + 0.5,
    cameraY = (playerY or 0) + 0.5,
    spriteScale = tileW / 16 * 0.82,
  }, Projection)
end

function Projection:cell(x, y, z)
  local dx = x - self.cameraX
  local dy = y - self.cameraY
  local sx = self.centerX + (dx - dy) * self.tileW * 0.5
  local sy = self.centerY + (dx + dy) * self.tileH * 0.5
             - (z or 0) * self.elevation
  return sx, sy
end

function Projection:worldPixel(wx, wy, z)
  return self:cell(wx / 16, wy / 16, z or 0)
end

function Projection:cellPolygon(x, y, z)
  local x1, y1 = self:cell(x, y, z)
  local x2, y2 = self:cell(x + 1, y, z)
  local x3, y3 = self:cell(x + 1, y + 1, z)
  local x4, y4 = self:cell(x, y + 1, z)
  return { x1, y1, x2, y2, x3, y3, x4, y4 }
end

return Projection
