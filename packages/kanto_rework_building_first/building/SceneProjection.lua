local SceneProjection = {}
SceneProjection.__index = SceneProjection

local CELL = 16

local PRESETS = {
  [1] = { fov = 39.0, pitch = 25.0, yaw = -17.0, distance = 18.8, centerY = 0.62, sprite = 0.96 },
  [2] = { fov = 37.0, pitch = 23.0, yaw = -18.0, distance = 18.0, centerY = 0.625, sprite = 0.98 },
  [3] = { fov = 35.5, pitch = 21.5, yaw = -18.0, distance = 17.5, centerY = 0.625, sprite = 1.00 },
}

local function radians(v) return v * math.pi / 180 end

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

function SceneProjection.new(ctx, level)
  ctx = assert(ctx, "scene projection needs ctx")
  local width = assert(tonumber(ctx.width), "scene projection needs ctx.width")
  local height = assert(tonumber(ctx.height), "scene projection needs ctx.height")
  level = math.max(1, math.min(3, math.floor(tonumber(level) or 1)))
  local p = PRESETS[level]
  local targetX, targetY = cameraCell(ctx)
  local pitch, yaw, fov = radians(p.pitch), radians(p.yaw), radians(p.fov)
  local cp, sp, cy, sy = math.cos(pitch), math.sin(pitch), math.cos(yaw), math.sin(yaw)
  local cameraX = targetX - sy * p.distance
  local cameraY = targetY + cy * p.distance
  local cameraZ = p.distance * math.tan(pitch)
  local focal = (width * 0.5) / math.tan(fov * 0.5)
  local targetDepth = p.distance / math.max(0.001, cp)
  local tileW = focal / targetDepth

  return setmetatable({
    width = width, height = height, level = level,
    centerX = width * 0.5, centerY = height * p.centerY,
    cameraX = cameraX, cameraY = cameraY, cameraZ = cameraZ,
    cosPitch = cp, sinPitch = sp, cosYaw = cy, sinYaw = sy,
    focal = focal, near = 0.35, tileW = tileW,
    spriteScale = tileW / CELL * p.sprite,
  }, SceneProjection)
end

function SceneProjection:cameraCoordinates(x, y, z)
  local dx, dy, dz = x - self.cameraX, y - self.cameraY, (z or 0) - self.cameraZ
  local right = dx * self.cosYaw + dy * self.sinYaw
  local forward = dx * self.sinYaw - dy * self.cosYaw
  return right,
         forward * self.sinPitch + dz * self.cosPitch,
         forward * self.cosPitch - dz * self.sinPitch
end

function SceneProjection:cell(x, y, z)
  local cx, cy, cz = self:cameraCoordinates(x, y, z)
  cz = math.max(self.near, cz)
  local k = self.focal / cz
  return self.centerX + cx * k, self.centerY - cy * k
end

function SceneProjection:worldPixel(wx, wy, z)
  return self:cell(wx / CELL, wy / CELL, z or 0)
end

function SceneProjection:cellPolygon(x, y, z)
  local ax, ay = self:cell(x, y, z)
  local bx, by = self:cell(x + 1, y, z)
  local cx, cy = self:cell(x + 1, y + 1, z)
  local dx, dy = self:cell(x, y + 1, z)
  return { ax, ay, bx, by, cx, cy, dx, dy }
end

function SceneProjection:depth(x, y, bias)
  local _, _, cz = self:cameraCoordinates(x, y, 0)
  return -cz + (bias or 0)
end

return SceneProjection
