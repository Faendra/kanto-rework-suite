local WorldEnvelope = {}

-- WORLD-ENVELOPE-01
--
-- The gameplay maps remain the only authoritative world rectangles.  This
-- module creates VISUAL-ONLY objects outside those rectangles so the 3/4
-- camera never exposes a flat map sheet floating in sky.  It deliberately
-- does not infer collisions, warps, walkability or new gameplay terrain.
--
-- For OVERWORLD scenes the first envelope type is a dense forest belt made
-- from authored tree-cluster instances.  Connected maps supplied by
-- Gen1Recomp are part of the occupied world, so the belt automatically leaves
-- their seams open instead of painting trees over a real connection.

local DEFAULT_DEPTH = 10
local CLUSTER_STEP = 2
local CLUSTER_WIDTH = 1.85
local CLUSTER_HEIGHT = 3.15

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

local function deterministicJitter(ix, iy)
  -- Small deterministic offsets break the obvious square lattice without
  -- introducing frame-to-frame noise or any dependency on math.random state.
  local a = ((ix * 37 + iy * 17) % 7) - 3
  local b = ((ix * 13 + iy * 29) % 5) - 2
  return a * 0.035, b * 0.045
end

function WorldEnvelope.build(state, scenes, depth)
  local out = {
    kind = "none",
    trees = {},
    depth = 0,
    bounds = nil,
  }
  if not forestMode(state) then return out end

  local rects, bounds = worldRects(scenes)
  if not bounds or #rects == 0 then return out end

  depth = math.max(2, math.floor(tonumber(depth) or DEFAULT_DEPTH))
  out.kind = "forest"
  out.depth = depth
  out.bounds = {
    x0 = math.floor(bounds.x0 - depth),
    y0 = math.floor(bounds.y0 - depth),
    x1 = math.ceil(bounds.x1 + depth),
    y1 = math.ceil(bounds.y1 + depth),
  }

  local row = 0
  local y = out.bounds.y0
  while y < out.bounds.y1 do
    local stagger = (row % 2 == 0) and 0 or 0.72
    local col = 0
    local x = out.bounds.x0
    while x < out.bounds.x1 do
      local cx = x + CLUSTER_STEP * 0.5 + stagger
      local cy = y + CLUSTER_STEP * 0.62
      if not insideAny(rects, cx, cy) then
        local d = distanceToWorld(rects, cx, cy)
        if d <= depth + 0.75 then
          local jx, jy = deterministicJitter(col + row * 97, row)
          out.trees[#out.trees + 1] = {
            kind = "tree_cluster",
            x = cx + jx,
            y = cy + jy,
            z = 0,
            width = CLUSTER_WIDTH,
            height = CLUSTER_HEIGHT,
            row = row,
          }
        end
      end
      col = col + 1
      x = x + CLUSTER_STEP
    end
    row = row + 1
    y = y + CLUSTER_STEP
  end

  return out
end

WorldEnvelope.DEFAULT_DEPTH = DEFAULT_DEPTH
WorldEnvelope.CLUSTER_STEP = CLUSTER_STEP

return WorldEnvelope
