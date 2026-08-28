local SceneProjection = {}
SceneProjection.__index = SceneProjection

local CELL = 16

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- The visual target needs a camera that reads as a miniature 3D world, not a
-- tactical map. Ground diamonds therefore stay relatively shallow while world
-- elevation is amplified, and each level moves the camera closer rather than
-- simply exaggerating a flat perspective warp.
local PRESETS = {
  [1] = { zoom = 1.02, ratio = 0.38, elevation = 1.65, centerY = 0.56, sprite = 0.84 },
  [2] = { zoom = 1.12, ratio = 0.40, elevation = 1.85, centerY = 0.58, sprite = 0.88 },
  [3] = { zoom = 1.22, ratio = 0.42, elevation = 2.05, centerY = 0.60, sprite = 0.92 },
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

function SceneProjection.new(ctx, level)
  ctx = assert(ctx, "scene projection needs ctx")
  local width = assert(tonumber(ctx.width), "scene projection needs ctx.width")
  local height = assert(tonumber(ctx.height), "scene projection needs ctx.height")
  level = math.max(1, math.min(3, math.floor(tonumber(level) or 1)))
  local preset = PRESETS[level]

  -- True isometric world basis: X and Y rotate toward opposite horizontal
  -- directions while both recede vertically. A rectangular Gen I map therefore
  -- becomes a spatial diorama instead of a trapezoid with fake depth bands.
  local base = clamp(math.min(width / 16.0, height / 9.5), 30, 76)
  local tileW = base * preset.zoom
  local tileH = tileW * preset.ratio
  local cameraX, cameraY = cameraCell(ctx)

  return setmetatable({
    width = width,
    height = height,
    level = level,
    tileW = tileW,
    tileH = tileH,
    elevation = tileH * preset.elevation,
    centerX = width * 0.50,
    centerY = height * preset.centerY,
    cameraX = cameraX,
    cameraY = cameraY,
    spriteScale = tileW / CELL * preset.sprite,
  }, SceneProjection)
end

function SceneProjection:cell(x, y, z)
  local dx = x - self.cameraX
  local dy = y - self.cameraY
  local sx = self.centerX + (dx - dy) * self.tileW * 0.5
  local sy = self.centerY + (dx + dy) * self.tileH * 0.5
             - (z or 0) * self.elevation
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

function SceneProjection:depth(x, y, bias)
  return x + y + (bias or 0)
end

function SceneProjection:visibleRadius()
  local rx = math.ceil(self.width / math.max(1, self.tileW)) + 4
  local ry = math.ceil(self.height / math.max(1, self.tileH)) * 0.5 + 4
  return math.max(8, math.ceil(math.max(rx, ry)))
end

return SceneProjection
