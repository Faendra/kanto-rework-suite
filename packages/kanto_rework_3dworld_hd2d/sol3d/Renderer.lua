local Projection = require("sol3d.Projection")
local SceneProfiles = require("sol3d.SceneProfiles")

local Renderer = {}
Renderer.__index = Renderer

local BASE = {
  ground = { 0.55, 0.68, 0.43 },
  blocked = { 0.40, 0.47, 0.34 },
  water = { 0.30, 0.57, 0.70 },
  warp = { 0.63, 0.64, 0.43 },
  side = { 0.28, 0.33, 0.25 },
  waterSide = { 0.19, 0.37, 0.48 },
  trunk = { 0.34, 0.24, 0.16 },
  canopy = { 0.20, 0.43, 0.27 },
  canopyTop = { 0.29, 0.55, 0.34 },
  houseWall = { 0.76, 0.70, 0.54 },
  houseRoof = { 0.55, 0.25, 0.20 },
  labWall = { 0.70, 0.72, 0.63 },
  labRoof = { 0.28, 0.42, 0.48 },
  door = { 0.24, 0.19, 0.16 },
  window = { 0.45, 0.68, 0.72 },
}

local TYPE_RANK = { cell = 1, vegetation = 2, structure = 2, actor = 3 }

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function setColor(c, mul)
  mul = mul or 1
  love.graphics.setColor(clamp(c[1] * mul, 0, 1),
                         clamp(c[2] * mul, 0, 1),
                         clamp(c[3] * mul, 0, 1), 1)
end

local function cellKind(ch)
  if ch == "~" then return "water" end
  if ch == "+" then return "warp" end
  if ch == "." then return "ground" end
  return "blocked"
end

local function heightFor(kind)
  if kind == "water" then return -0.14 end
  if kind == "blocked" then return 0.10 end
  return 0
end

local function cellChar(overview, x, y)
  if x < 0 or y < 0 or x >= overview.width or y >= overview.height then
    return nil
  end
  local row = overview.rows and overview.rows[y + 1]
  return row and row:sub(x + 1, x + 1) or nil
end

local function surfaceKind(profile, overview, x, y)
  local k = SceneProfiles.cellKey(x, y)
  if profile.structureCells[k] or profile.vegetationCells[k] then
    return "ground"
  end
  return cellKind(cellChar(overview, x, y))
end

local function surfaceHeight(profile, overview, x, y)
  return heightFor(surfaceKind(profile, overview, x, y))
end

local function detailDigit(overview, x, y, sx, sy)
  local rows = overview.tileDetailRows
  if not rows then return nil end
  local row = rows[y * 4 + sy + 1]
  if not row then return nil end
  return tonumber(row:sub(x * 4 + sx + 1, x * 4 + sx + 1))
end

local function topColor(kind, shade)
  local base = BASE[kind] or BASE.ground
  local value = 1.10 - (shade or 1.5) * 0.105
  return clamp(base[1] * value, 0, 1),
         clamp(base[2] * value, 0, 1),
         clamp(base[3] * value, 0, 1), 1
end

local function drawPoly(points)
  love.graphics.polygon("fill", points)
end

local function drawDetailedTop(proj, overview, x, y, z, kind)
  if not overview.tileDetailRows then
    love.graphics.setColor(topColor(kind, 1.5))
    drawPoly(proj:cellPolygon(x, y, z))
    return
  end

  -- 4x4 shade texels per 16px walk cell.  Geometry remains one continuous
  -- plane; only the material sampling is pixelated, so the result reads as
  -- pixel art laid onto 3D rather than sixteen tiny cubes.
  for sy = 0, 3 do
    for sx = 0, 3 do
      local shade = detailDigit(overview, x, y, sx, sy) or 1.5
      love.graphics.setColor(topColor(kind, shade))
      local x0, y0 = x + sx / 4, y + sy / 4
      drawPoly(proj:quad(x0, y0, x0 + 0.25, y0 + 0.25, z))
    end
  end
end

local function drawSide(proj, x, y, zTop, zBottom, edge, kind)
  if zBottom >= zTop then return end
  local a1, b1, a2, b2, c1, d1, c2, d2
  if edge == "east" then
    a1, b1 = proj:cell(x + 1, y, zTop)
    a2, b2 = proj:cell(x + 1, y + 1, zTop)
    c1, d1 = proj:cell(x + 1, y, zBottom)
    c2, d2 = proj:cell(x + 1, y + 1, zBottom)
  else
    a1, b1 = proj:cell(x, y + 1, zTop)
    a2, b2 = proj:cell(x + 1, y + 1, zTop)
    c1, d1 = proj:cell(x, y + 1, zBottom)
    c2, d2 = proj:cell(x + 1, y + 1, zBottom)
  end
  setColor(kind == "water" and BASE.waterSide or BASE.side)
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
  return (pose.px + 8) / 16 + (pose.actor.py + 12) / 16 + 0.04
end

local function actorSurfaceZ(profile, overview, pose)
  local cx = math.floor((pose.px + 8) / 16)
  local cy = math.floor((pose.actor.py + 12) / 16)
  local kind = surfaceKind(profile, overview, cx, cy)
  return kind == "water" and heightFor("water") or 0
end

local function drawActor(proj, profile, overview, pose)
  local actor, sprite = pose.actor, pose.sprite
  local groundPx, groundPy = pose.px + 8, actor.py + 12
  local lift = 0
  if pose.hopping and actor.py and pose.py then
    lift = math.max(0, actor.py - pose.py) / 16
  end
  local z = actorSurfaceZ(profile, overview, pose) + lift
  local sx, sy = proj:worldPixel(groundPx, groundPy, z)
  local geometry = sprite:getPoseGeometry(pose.facing, pose.phase, pose.flip)
  local image = sprite:resolveImage()
  if not (geometry and geometry.quad and image) then return end

  local s = proj.spriteScale
  love.graphics.setColor(0, 0, 0, 0.20)
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

local function drawVerticalBillboard(proj, x, y, z0, z1, halfWidth, color)
  local bx, by = proj:cell(x, y, z0)
  local tx, ty = proj:cell(x, y, z1)
  setColor(color)
  drawPoly({ bx - halfWidth, by, bx + halfWidth, by,
             tx + halfWidth, ty, tx - halfWidth, ty })
end

local function drawVegetation(proj, x, y, level)
  local depthScale = ({ 0.90, 1.00, 1.08 })[level] or 1
  local cx, cy = x + 0.5, y + 0.5
  drawVerticalBillboard(proj, cx, cy, 0, 0.40 * depthScale,
                        proj.tileW * 0.055, BASE.trunk)

  local z1, z2 = 0.34 * depthScale, 0.58 * depthScale
  setColor(BASE.canopy, 0.86)
  drawPoly(proj:quad(x + 0.10, y + 0.10, x + 0.90, y + 0.90, z1))
  setColor(BASE.canopy)
  drawPoly(proj:quad(x + 0.17, y + 0.17, x + 0.83, y + 0.83, z2))
  setColor(BASE.canopyTop, 1.03)
  drawPoly(proj:quad(x + 0.27, y + 0.27, x + 0.73, y + 0.73,
                     z2 + 0.19 * depthScale))
end

local function southWallQuad(proj, x0, x1, y, z0, z1)
  local ax, ay = proj:cell(x0, y, z0)
  local bx, by = proj:cell(x1, y, z0)
  local cx, cy = proj:cell(x1, y, z1)
  local dx, dy = proj:cell(x0, y, z1)
  return { ax, ay, bx, by, cx, cy, dx, dy }
end

local function eastWallQuad(proj, x, y0, y1, z0, z1)
  local ax, ay = proj:cell(x, y0, z0)
  local bx, by = proj:cell(x, y1, z0)
  local cx, cy = proj:cell(x, y1, z1)
  local dx, dy = proj:cell(x, y0, z1)
  return { ax, ay, bx, by, cx, cy, dx, dy }
end

local function drawSouthPanel(proj, x0, x1, y, z0, z1, color)
  setColor(color)
  drawPoly(southWallQuad(proj, x0, x1, y + 0.002, z0, z1))
end

local function drawStructure(proj, s, level)
  local scale = ({ 0.92, 1.00, 1.08 })[level] or 1
  local wallZ = (s.kind == "lab" and 0.72 or 0.62) * scale
  local ridgeZ = wallZ + (s.kind == "lab" and 0.43 or 0.50) * scale
  local wall = s.kind == "lab" and BASE.labWall or BASE.houseWall
  local roof = s.kind == "lab" and BASE.labRoof or BASE.houseRoof
  local x0, x1 = s.x, s.x + s.w
  local y0, y1 = s.y, s.y + s.h
  local ridgeY = (y0 + y1) * 0.5

  setColor(wall, 0.86)
  drawPoly(eastWallQuad(proj, x1, y0, y1, 0, wallZ))
  setColor(wall)
  drawPoly(southWallQuad(proj, x0, x1, y1, 0, wallZ))

  -- Gabled roof: two large slopes, not a stack of map-cell cubes.
  local a1, a2 = proj:cell(x0, y0, wallZ)
  local b1, b2 = proj:cell(x1, y0, wallZ)
  local c1, c2 = proj:cell(x1, ridgeY, ridgeZ)
  local d1, d2 = proj:cell(x0, ridgeY, ridgeZ)
  setColor(roof, 1.06)
  drawPoly({ a1, a2, b1, b2, c1, c2, d1, d2 })

  local e1, e2 = proj:cell(x0, y1, wallZ)
  local f1, f2 = proj:cell(x1, y1, wallZ)
  setColor(roof, 0.90)
  drawPoly({ d1, d2, c1, c2, f1, f2, e1, e2 })

  -- Doors are derived from the map's real warp coordinates.  They are visual
  -- decoration only; the engine still owns the warp itself.
  for _, door in ipairs(s.doors or {}) do
    drawSouthPanel(proj, door.x + 0.12, door.x + 0.88, y1,
                   0.02, wallZ * 0.72, BASE.door)
  end

  -- A restrained front-window rhythm makes the large silhouettes read as
  -- buildings without requiring replacement art in the technical pilot.
  local windowZ0, windowZ1 = wallZ * 0.40, wallZ * 0.66
  local windowCount = s.kind == "lab" and 3 or 2
  for i = 1, windowCount do
    local center = x0 + s.w * i / (windowCount + 1)
    local blockedByDoor = false
    for _, door in ipairs(s.doors or {}) do
      if math.abs(center - (door.x + 0.5)) < 0.75 then blockedByDoor = true end
    end
    if not blockedByDoor then
      drawSouthPanel(proj, center - 0.28, center + 0.28, y1,
                     windowZ0, windowZ1, BASE.window)
    end
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
    cameraX = nil,
    cameraY = nil,
    targetCameraX = nil,
    targetCameraY = nil,
    lastMapId = nil,
  }, Renderer)
end

function Renderer:available()
  return love and love.graphics
    and type(love.graphics.newCanvas) == "function"
    and type(love.graphics.setCanvas) == "function"
    and type(love.graphics.polygon) == "function"
end

function Renderer:update(dt, level)
  self.level = math.max(0, math.min(3, math.floor(tonumber(level) or 0)))
  if self.cameraX and self.targetCameraX then
    local seconds = math.max(0, tonumber(dt) or 0)
    local t = 1 - math.exp(-seconds * 10)
    self.cameraX = self.cameraX + (self.targetCameraX - self.cameraX) * t
    self.cameraY = self.cameraY + (self.targetCameraY - self.cameraY) * t
  end
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

  local state = ctx.state
  local profile = SceneProfiles.build(snapshot)
  local playerPose = actorPose(state.player)
  local targetX = snapshot.player.x + 0.5
  local targetY = snapshot.player.y + 0.5
  if playerPose then
    targetX = (playerPose.px + 8) / 16
    targetY = (playerPose.actor.py + 12) / 16
  end
  self.targetCameraX, self.targetCameraY = targetX, targetY
  if self.lastMapId ~= snapshot.mapId or not self.cameraX then
    self.cameraX, self.cameraY = targetX, targetY
    self.lastMapId = snapshot.mapId
  end

  local canvas = self:ensureCanvas(ctx.width, ctx.height)
  local proj = Projection.new(ctx.width, ctx.height, self.level,
                              self.cameraX, self.cameraY)

  local previous = love.graphics.getCanvas and love.graphics.getCanvas() or nil
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.055, 0.075, 0.082, 1)

  local radius = ({ 14, 17, 20 })[self.level] or 14
  local minX = math.max(0, math.floor(targetX) - radius)
  local maxX = math.min(overview.width - 1, math.floor(targetX) + radius)
  local minY = math.max(0, math.floor(targetY) - radius)
  local maxY = math.min(overview.height - 1, math.floor(targetY) + radius)

  local drawables = {}
  for y = minY, maxY do
    for x = minX, maxX do
      drawables[#drawables + 1] = {
        type = "cell", x = x, y = y, depth = x + y,
      }
      if profile.vegetationCells[SceneProfiles.cellKey(x, y)] then
        drawables[#drawables + 1] = {
          type = "vegetation", x = x, y = y, depth = x + y + 0.92,
        }
      end
    end
  end

  for _, structure in ipairs(profile.structures) do
    local frontDepth = structure.x + structure.w - 1
                     + structure.y + structure.h - 1
    drawables[#drawables + 1] = {
      type = "structure", structure = structure, depth = frontDepth + 0.02,
    }
  end

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
    return (TYPE_RANK[a.type] or 9) < (TYPE_RANK[b.type] or 9)
  end)

  local cellsDrawn, actorsDrawn = 0, 0
  local vegetationDrawn, structuresDrawn = 0, 0
  for _, item in ipairs(drawables) do
    if item.type == "cell" then
      local x, y = item.x, item.y
      local kind = surfaceKind(profile, overview, x, y)
      local z = heightFor(kind)
      local east = surfaceHeight(profile, overview, x + 1, y)
      local south = surfaceHeight(profile, overview, x, y + 1)
      drawSide(proj, x, y, z, east, "east", kind)
      drawSide(proj, x, y, z, south, "south", kind)
      drawDetailedTop(proj, overview, x, y, z, kind)
      cellsDrawn = cellsDrawn + 1
    elseif item.type == "vegetation" then
      drawVegetation(proj, item.x, item.y, self.level)
      vegetationDrawn = vegetationDrawn + 1
    elseif item.type == "structure" then
      drawStructure(proj, item.structure, self.level)
      structuresDrawn = structuresDrawn + 1
    else
      drawActor(proj, profile, overview, item.pose)
      actorsDrawn = actorsDrawn + 1
    end
  end

  if ctx.drawFx then
    love.graphics.setColor(1, 1, 1, 1)
    ctx.drawFx(function(wx, wy)
      local cx, cy = math.floor(wx / 16), math.floor(wy / 16)
      local z = surfaceKind(profile, overview, cx, cy) == "water"
        and heightFor("water") or 0
      return proj:worldPixel(wx, wy, z)
    end, proj.spriteScale)
  end

  love.graphics.setCanvas(previous)
  love.graphics.setColor(1, 1, 1, 1)

  self.lastStats = {
    mapId = snapshot.mapId,
    profile = profile.name,
    cells = cellsDrawn,
    actors = actorsDrawn,
    vegetation = vegetationDrawn,
    structures = structuresDrawn,
    level = self.level,
    width = ctx.width,
    height = ctx.height,
  }
  return canvas
end

return Renderer
