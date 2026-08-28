local SceneProjection = {}
SceneProjection.__index = SceneProjection

local CELL = 16

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local PRESETS = {
  [1] = { fov = 40, pitch = 32, yaw = -14, distance = 20.5, centerY = 0.60, sprite = 0.92 },
  [2] = { fov = 38, pitch = 28, yaw = -16, distance = 19.0, centerY = 0.61, sprite = 0.96 },
  [3] = { fov = 36, pitch = 25, yaw = -18, distance = 17.5, centerY = 0.62, sprite = 1.00 },
}

local function cameraCell(ctx)
  local state = ctx and ctx.state
  local player = state and state.player
  if player and type(player.px) == "number" and type(player.py) == "number" then
    return (player.px + 8) / CELL, (player.py + 12) / CELL
  end

  local cam = ctx and ctx.cam or {}
  local vw = tonumber(ctx and ctx.vw) or 160
  local vh = tonumber(ctx and ctx.vh) or 144
  return ((tonumber(cam.x) or 0) + vw * 0.5) / CELL,
         ((tonumber(ctx and ctx.bgY) or tonumber(cam.y) or 0) + vh * 0.5) / CELL
end

local function radians(deg)
  return deg * math.pi / 180
end

function SceneProjection.new(ctx, level)
  ctx = assert(ctx, "scene projection needs ctx")
  local width = assert(tonumber(ctx.width), "scene projection needs ctx.width")
  local height = assert(tonumber(ctx.height), "scene projection needs ctx.height")
  level = math.max(1, math.min(3, math.floor(tonumber(level) or 1)))
  local preset = PRESETS[level]
  local targetX, targetY = cameraCell(ctx)
  local pitch = radians(preset.pitch)
  local yaw = radians(preset.yaw)
  local fov = radians(preset.fov)
  local cosPitch = math.cos(pitch)
  local sinPitch = math.sin(pitch)
  local cosYaw = math.cos(yaw)
  local sinYaw = math.sin(yaw)
  local distance = preset.distance

  local cameraX = targetX - sinYaw * distance
  local cameraY = targetY + cosYaw * distance
  local cameraZ = distance * math.tan(pitch)
  local focal = (width * 0.5) / math.tan(fov * 0.5)
  local targetDepth = distance / math.max(0.001, cosPitch)
  local tileW = focal / targetDepth
  local tileH = tileW * sinPitch
  local elevation = tileW * cosPitch

  return setmetatable({
    width = width,
    height = height,
    level = level,
    centerX = width * 0.50,
    centerY = height * preset.centerY,
    cameraX = cameraX,
    cameraY = cameraY,
    cameraZ = cameraZ,
    targetX = targetX,
    targetY = targetY,
    cosPitch = cosPitch,
    sinPitch = sinPitch,
    cosYaw = cosYaw,
    sinYaw = sinYaw,
    focal = focal,
    near = 0.35,
    tileW = tileW,
    tileH = tileH,
    elevation = elevation,
    spriteFactor = preset.sprite,
    spriteScale = tileW / CELL * preset.sprite,
  }, SceneProjection)
end

function SceneProjection:cameraCoordinates(x, y, z)
  local dx = x - self.cameraX
  local dy = y - self.cameraY
  local dz = (z or 0) - self.cameraZ

  local right = dx * self.cosYaw + dy * self.sinYaw
  local forward = dx * self.sinYaw - dy * self.cosYaw
  local cx = right
  local cy = forward * self.sinPitch + dz * self.cosPitch
  local cz = forward * self.cosPitch - dz * self.sinPitch
  return cx, cy, cz
end

function SceneProjection:cell(x, y, z)
  local cx, cy, cz = self:cameraCoordinates(x, y, z)
  cz = math.max(self.near, cz)
  local k = self.focal / cz
  local sx = self.centerX + cx * k
  local sy = self.centerY - cy * k
  return sx, sy
end

function SceneProjection:worldPixel(wx, wy, z)
  return self:cell(wx / CELL, wy / CELL, z or 0)
end

function SceneProjection:quad(x0, y0, x1, y1, z)
  local ax, ay = self:cell(x0, y0, z)
  local bx, by = self:cell(x1, y0, z)
  local cx, cy = self:cell(x1, y1, z)
  local dx, dy = self:cell(x0, y1, z)
  return { ax, ay, bx, by, cx, cy, dx, dy }
end

function SceneProjection:cellPolygon(x, y, z)
  return self:quad(x, y, x + 1, y + 1, z)
end

function SceneProjection:screenScale(x, y, z)
  local _, _, cz = self:cameraCoordinates(x, y, z or 0)
  return self.focal / math.max(self.near, cz)
end

function SceneProjection:spriteScaleAt(x, y, z)
  return self:screenScale(x, y, z or 0) / CELL * self.spriteFactor
end

function SceneProjection:depth(x, y, bias)
  local _, _, cz = self:cameraCoordinates(x, y, 0)
  return -cz + (bias or 0)
end

function SceneProjection:visibleRadius()
  local rx = math.ceil(self.width / math.max(1, self.tileW)) * 0.70 + 7
  local ry = math.ceil(self.height / math.max(1, self.tileH)) * 0.70 + 9
  return math.max(11, math.ceil(math.max(rx, ry)))
end

return SceneProjection
