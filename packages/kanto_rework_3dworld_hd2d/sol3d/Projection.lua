local Projection = {}
Projection.__index = Projection

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function Projection.new(width, height, level, cameraX, cameraY)
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
    cameraX = cameraX or 0,
    cameraY = cameraY or 0,
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

function Projection:quad(x0, y0, x1, y1, z)
  local ax, ay = self:cell(x0, y0, z)
  local bx, by = self:cell(x1, y0, z)
  local cx, cy = self:cell(x1, y1, z)
  local dx, dy = self:cell(x0, y1, z)
  return { ax, ay, bx, by, cx, cy, dx, dy }
end

function Projection:cellPolygon(x, y, z)
  return self:quad(x, y, x + 1, y + 1, z)
end

return Projection
