local WorldEnvelope = {}

-- WORLD-ENVELOPE-01
--
-- Gameplay maps remain the only authoritative world rectangles. This module
-- creates VISUAL-ONLY objects outside them so the 3/4 camera reads a larger
-- environment instead of a rectangular map sheet. No collision, warp,
-- walkability or gameplay terrain is created here.

local DEFAULT_DEPTH = 7
local TREE_STEP = 1.38
local TREE_WIDTH = 1.78
local MIN_DISTANCE = 0.30

local function rectFor(scene)
  local map = scene and scene.map
  if not map then return nil end
  local x0 = tonumber(scene.cx) or 0
  local y0 = tonumber(scene.cy) or 0
  return {
    x0 = x0,
    y0 = y0,
    x1 = x0 + (tonumber(map.widthCells) or 0),
    y1 = y0 + (tonumber(map.heightCells) or 0),
  }
end

local function contains(rect, x, y)
  return rect and x >= rect.x0 and x < rect.x1 and y >= rect.y0 and y < rect.y1
end

local function distanceToRect(rect, x, y)
  local dx = 0
  if x < rect.x0 then dx = rect.x0 - x
  elseif x > rect.x1 then dx = x - rect.x1 end
  local dy = 0
  if y < rect.y0 then dy = rect.y0 - y
  elseif y > rect.y1 then dy = y - rect.y1 end
  return math.sqrt(dx * dx + dy * dy)
end

local function forestMode(state)
  local map = state and state.map
  local def = map and map.def
  return def and def.tileset == "OVERWORLD"
end

local function worldRects(scenes)
  local rects = {}
  local minX, minY, maxX, maxY
  for _, scene in ipairs(scenes or {}) do
    local rect = rectFor(scene)
    if rect then
      rects[#rects + 1] = rect
      minX = minX and math.min(minX, rect.x0) or rect.x0
      minY = minY and math.min(minY, rect.y0) or rect.y0
      maxX = maxX and math.max(maxX, rect.x1) or rect.x1
      maxY = maxY and math.max(maxY, rect.y1) or rect.y1
    end
  end
  if not minX then return rects, nil end
  return rects, { x0 = minX, y0 = minY, x1 = maxX, y1 = maxY }
end

local function insideAny(rects, x, y)
  for i = 1, #rects do
    if contains(rects[i], x, y) then return true end
  end
  return false
end

local function distanceToWorld(rects, x, y)
  local best
  for i = 1, #rects do
    local d = distanceToRect(rects[i], x, y)
    best = best and math.min(best, d) or d
  end
  return best or math.huge
end

local function hash(ix, iy)
  return math.abs(ix * 73856093 + iy * 19349663) % 104729
end

local function deterministicJitter(ix, iy)
  local h = hash(ix, iy)
  local a = (h % 17) - 8
  local b = (math.floor(h / 17) % 13) - 6
  return a * 0.018, b * 0.018, h
end

function WorldEnvelope.build(state, scenes, depth)
  local out = { kind = "none", trees = {}, depth = 0, bounds = nil }
  if not forestMode(state) then return out end

  local rects, bounds = worldRects(scenes)
  if not bounds or #rects == 0 then return out end

  depth = math.max(2, tonumber(depth) or DEFAULT_DEPTH)
  out.kind = "forest"
  out.depth = depth
  out.bounds = {
    x0 = bounds.x0 - depth,
    y0 = bounds.y0 - depth,
    x1 = bounds.x1 + depth,
    y1 = bounds.y1 + depth,
  }

  local row, y = 0, out.bounds.y0
  while y < out.bounds.y1 do
    local stagger = (row % 2 == 0) and 0 or TREE_STEP * 0.48
    local col, x = 0, out.bounds.x0
    while x < out.bounds.x1 do
      local cx = x + TREE_STEP * 0.5 + stagger
      local cy = y + TREE_STEP * 0.60
      if not insideAny(rects, cx, cy) then
        local d = distanceToWorld(rects, cx, cy)
        if d >= MIN_DISTANCE and d <= depth + TREE_STEP * 0.8 then
          local jx, jy, h = deterministicJitter(col + row * 97, row)
          local size = 0.93 + (h % 7) * 0.022
          out.trees[#out.trees + 1] = {
            kind = "tree",
            x = cx + jx,
            y = cy + jy,
            z = 0,
            width = TREE_WIDTH * size,
            row = row,
          }
        end
      end
      col = col + 1
      x = x + TREE_STEP
    end
    row = row + 1
    y = y + TREE_STEP
  end

  return out
end

WorldEnvelope.DEFAULT_DEPTH = DEFAULT_DEPTH
WorldEnvelope.TREE_STEP = TREE_STEP

return WorldEnvelope
