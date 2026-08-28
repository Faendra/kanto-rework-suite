local Projection = require("sol3d.Projection")

local Renderer = {}
Renderer.__index = Renderer

local BASE = {
  ground = { 0.50, 0.68, 0.42 },
  blocked = { 0.25, 0.43, 0.30 },
  water = { 0.31, 0.58, 0.70 },
  warp = { 0.57, 0.63, 0.43 },
  side = { 0.22, 0.31, 0.24 },
  waterSide = { 0.20, 0.39, 0.50 },
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function cellKind(ch)
  if ch == "~" then return "water" end
  if ch == "+" then return "warp" end
  if ch == "." then return "ground" end
  return "blocked"
end

local function heightFor(kind, level)
  if kind == "water" then return -0.16 end
  if kind == "blocked" then
    return ({ 0.42, 0.62, 0.78 })[level] or 0.42
  end
  if kind == "warp" then return 0.015 end
  return 0
end

local function cellChar(overview, x, y)
  if x < 0 or y < 0 or x >= overview.width or y >= overview.height then
    return nil
  end
  local row = overview.rows and overview.rows[y + 1]
  return row and row:sub(x + 1, x + 1) or nil
end

local function cellHeight(overview, x, y, level)
  local ch = cellChar(overview, x, y)
  if ch == nil then return -0.25 end
  return heightFor(cellKind(ch), level)
end

local function detailShade(overview, x, y)
  local rows = overview.tileDetailRows
  if not rows then return 0.5 end
  local total, count = 0, 0
  local ox, oy = x * 4, y * 4
  for dy = 0, 3 do
    local row = rows[oy + dy + 1]
    if row then
      for dx = 0, 3 do
        local digit = tonumber(row:sub(ox + dx + 1, ox + dx + 1))
        if digit then
          total = total + digit
          count = count + 1
        end
      end
    end
  end
  if count == 0 then return 0.5 end
  return total / (count * 3)
end

local function colorFor(kind, shade)
  local base = BASE[kind] or BASE.ground
  local value = 1.08 - shade * 0.36
  return clamp(base[1] * value, 0, 1),
         clamp(base[2] * value, 0, 1),
         clamp(base[3] * value, 0, 1), 1
end

local function drawPoly(points)
  love.graphics.polygon("fill", points)
end

local function drawSide(proj, x, y, zTop, zBottom, edge, kind)
  if zBottom >= zTop then return end
  local a1, b1, a2, b2
  if edge == "east" then
    a1, b1 = proj:cell(x + 1, y, zTop)
    a2, b2 = proj:cell(x + 1, y + 1, zTop)
  else
    a1, b1 = proj:cell(x, y + 1, zTop)
    a2, b2 = proj:cell(x + 1, y + 1, zTop)
  end
  local c2, d2
  local c1, d1
  if edge == "east" then
    c1, d1 = proj:cell(x + 1, y, zBottom)
    c2, d2 = proj:cell(x + 1, y + 1, zBottom)
  else
    c1, d1 = proj:cell(x, y + 1, zBottom)
    c2, d2 = proj:cell(x + 1, y + 1, zBottom)
  end
  local side = kind == "water" and BASE.waterSide or BASE.side
  love.graphics.setColor(side[1], side[2], side[3], 1)
  drawPoly({ a1, b1, a2, b2, c2, d2, c1, d1 })
end

local function actorPose(actor)
  if not (actor and actor.pose) then return nil end
  local sprite, px, py, facing, phase, flip, hopping = actor:pose()
  if not (sprite and sprite.getPoseGeometry and sprite.resolveImage) then
    return nil
  end
  return {
    actor = actor,
    sprite = sprite,
    px = px,
    py = py,
    facing = facing,
    phase = phase,
    flip = flip,
    hopping = hopping,
  }
end

local function actorDepth(pose)
  return (pose.px + 8) / 16 + (pose.actor.py + 12) / 16 + 0.02
end

local function drawActor(proj, pose)
  local actor, sprite = pose.actor, pose.sprite
  local groundPx, groundPy = pose.px + 8, actor.py + 12
  local lift = 0
  if pose.hopping and actor.py and pose.py then
    lift = math.max(0, actor.py - pose.py) / 16
  end
  local sx, sy = proj:worldPixel(groundPx, groundPy, lift)
  local geometry = sprite:getPoseGeometry(pose.facing, pose.phase, pose.flip)
  local image = sprite:resolveImage()
  if not (geometry and geometry.quad and image) then return end

  local s = proj.spriteScale
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.ellipse("fill", sx, sy + 1, 6 * s, 2.2 * s)

  love.graphics.setColor(1, 1, 1, 1)
  local y = sy - geometry.anchorY * s
  if geometry.mirror then
    local x = sx + (geometry.width - geometry.anchorX) * s
    love.graphics.draw(image, geometry.quad, x, y, 0, -s, s)
  else
    local x = sx - geometry.anchorX * s
    love.graphics.draw(image, geometry.quad, x, y, 0, s, s)
  end
end

function Renderer.new(adapter)
  return setmetatable({
    adapter = adapter,
    canvas = nil,
    canvasW = 0,
    canvasH = 0,
    level = 0,
    lastStats = {},
  }, Renderer)
end

function Renderer:available()
  return love and love.graphics
    and type(love.graphics.newCanvas) == "function"
    and type(love.graphics.setCanvas) == "function"
    and type(love.graphics.polygon) == "function"
end

function Renderer:update(_, level)
  self.level = math.max(0, math.min(3, math.floor(tonumber(level) or 0)))
end

function Renderer:ensureCanvas(w, h)
  w, h = math.max(1, math.floor(w)), math.max(1, math.floor(h))
  if self.canvas and self.canvasW == w and self.canvasH == h then return self.canvas end
  if self.canvas and self.canvas.release then pcall(self.canvas.release, self.canvas) end
  self.canvas = love.graphics.newCanvas(w, h)
  if self.canvas.setFilter then self.canvas:setFilter("nearest", "nearest") end
  self.canvasW, self.canvasH = w, h
  return self.canvas
end

function Renderer:drawWorld(ctx)
  if self.level <= 0 then return nil end
  if not (ctx and ctx.width and ctx.height and ctx.state) then return nil end

  local snapshot = self.adapter:snapshot()
  if not snapshot then return nil end
  local overview = snapshot.overview
  if not (overview and overview.rows and overview.width and overview.height) then
    return nil
  end

  local canvas = self:ensureCanvas(ctx.width, ctx.height)
  local proj = Projection.new(ctx.width, ctx.height, self.level,
                              snapshot.player.x, snapshot.player.y)

  local previous = love.graphics.getCanvas and love.graphics.getCanvas() or nil
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.055, 0.075, 0.082, 1)

  local radius = ({ 14, 17, 20 })[self.level] or 14
  local minX = math.max(0, snapshot.player.x - radius)
  local maxX = math.min(overview.width - 1, snapshot.player.x + radius)
  local minY = math.max(0, snapshot.player.y - radius)
  local maxY = math.min(overview.height - 1, snapshot.player.y + radius)

  local drawables = {}
  for y = minY, maxY do
    for x = minX, maxX do
      drawables[#drawables + 1] = {
        type = "cell", x = x, y = y, depth = x + y,
      }
    end
  end

  local state = ctx.state
  local playerPose = actorPose(state.player)
  if playerPose then
    drawables[#drawables + 1] = {
      type = "actor", pose = playerPose, depth = actorDepth(playerPose),
    }
  end
  for _, npc in ipairs(state.npcs or {}) do
    local pose = actorPose(npc)
    if pose then
      drawables[#drawables + 1] = {
        type = "actor", pose = pose, depth = actorDepth(pose),
      }
    end
  end

  table.sort(drawables, function(a, b)
    if a.depth ~= b.depth then return a.depth < b.depth end
    if a.type ~= b.type then return a.type == "cell" end
    return false
  end)

  local cellsDrawn, actorsDrawn = 0, 0
  for _, item in ipairs(drawables) do
    if item.type == "cell" then
      local x, y = item.x, item.y
      local kind = cellKind(cellChar(overview, x, y))
      local z = heightFor(kind, self.level)
      local east = cellHeight(overview, x + 1, y, self.level)
      local south = cellHeight(overview, x, y + 1, self.level)
      drawSide(proj, x, y, z, east, "east", kind)
      drawSide(proj, x, y, z, south, "south", kind)
      love.graphics.setColor(colorFor(kind, detailShade(overview, x, y)))
      drawPoly(proj:cellPolygon(x, y, z))
      cellsDrawn = cellsDrawn + 1
    else
      drawActor(proj, item.pose)
      actorsDrawn = actorsDrawn + 1
    end
  end

  if ctx.drawFx then
    love.graphics.setColor(1, 1, 1, 1)
    ctx.drawFx(function(wx, wy)
      return proj:worldPixel(wx, wy, 0)
    end, proj.spriteScale)
  end

  love.graphics.setCanvas(previous)
  love.graphics.setColor(1, 1, 1, 1)

  self.lastStats = {
    mapId = snapshot.mapId,
    cells = cellsDrawn,
    actors = actorsDrawn,
    level = self.level,
    width = ctx.width,
    height = ctx.height,
  }
  return canvas
end

return Renderer
