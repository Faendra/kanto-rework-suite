local WorldEnvelope = {}

-- WORLD-ENVELOPE-01
--
-- Gameplay maps remain the only authoritative world rectangles. This module
-- creates VISUAL-ONLY objects outside them so the 3/4 camera reads a larger
-- environment instead of a rectangular map sheet. No collision, warp,
-- walkability or gameplay terrain is created here.
--
-- The envelope has two independent visual layers:
--   * a local forest floor, represented as row spans outside gameplay maps;
--   * billboard trees, denser near the authoritative world boundary.
--
-- The floor is deliberately NOT one huge texture quad. It is clipped around
-- every authoritative map rectangle, so connected maps remain real terrain
-- and no projected "sheet with holes" can drift out of alignment.

local DEFAULT_DEPTH = 7
local FLOOR_DEPTH = 4
local TREE_STEP = 1.30
local TREE_WIDTH = 1.96
local MIN_DISTANCE = 0.08
local INNER_BELT_DEPTH = 2.80
local FLOOR_Z = -0.035

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

local function hash(ix, iy, pass)
  return math.abs(ix * 73856093 + iy * 19349663 + (pass or 0) * 83492791) % 104729
end

local function deterministicJitter(ix, iy, pass)
  local h = hash(ix, iy, pass)
  local a = (h % 17) - 8
  local b = (math.floor(h / 17) % 13) - 6
  return a * 0.018, b * 0.018, h
end

local function addTree(out, rects, x, y, row, col, pass, maxDistance)
  if insideAny(rects, x, y) then return end
  local d = distanceToWorld(rects, x, y)
  if d < MIN_DISTANCE or d > maxDistance then return end

  local jx, jy, h = deterministicJitter(col + row * 97, row, pass)
  local size = 0.93 + (h % 7) * 0.022
  out.trees[#out.trees + 1] = {
    kind = "tree",
    x = x + jx,
    y = y + jy,
    z = 0,
    width = TREE_WIDTH * size,
    row = row,
    belt = pass == 0 and "outer" or "inner",
  }
end

local function populateTreePass(out, rects, pass, maxDistance)
  local step = TREE_STEP
  local phaseX = pass == 0 and 0 or step * 0.52
  local phaseY = pass == 0 and 0 or step * 0.46
  local row, y = 0, out.treeBounds.y0 + phaseY

  while y < out.treeBounds.y1 do
    local stagger = (row % 2 == 0) and 0 or step * 0.48
    local col, x = 0, out.treeBounds.x0 + phaseX
    while x < out.treeBounds.x1 do
      local cx = x + step * 0.5 + stagger
      local cy = y + step * 0.60
      addTree(out, rects, cx, cy, row, col, pass, maxDistance)
      col = col + 1
      x = x + step
    end
    row = row + 1
    y = y + step
  end
end

-- Build horizontal spans rather than one quad per cell. Adjacent floor cells
-- therefore read as a continuous forest bed and cost only a small number of
-- draw calls. Center-point occupancy is sufficient here because Gen1Recomp
-- map connections are cell-aligned in the world scene contract.
local function buildFloorRuns(rects, bounds)
  local floor = {}
  local x0 = math.floor(bounds.x0 - FLOOR_DEPTH)
  local y0 = math.floor(bounds.y0 - FLOOR_DEPTH)
  local x1 = math.ceil(bounds.x1 + FLOOR_DEPTH)
  local y1 = math.ceil(bounds.y1 + FLOOR_DEPTH)

  for y = y0, y1 - 1 do
    local runStart = nil
    for x = x0, x1 do
      local outside = x < x1 and not insideAny(rects, x + 0.5, y + 0.5)
      if outside and runStart == nil then
        runStart = x
      elseif not outside and runStart ~= nil then
        floor[#floor + 1] = {
          kind = "forest_floor",
          x0 = runStart,
          y0 = y,
          x1 = x,
          y1 = y + 1,
          z = FLOOR_Z,
        }
        runStart = nil
      end
    end
  end

  return floor, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

function WorldEnvelope.build(state, scenes, depth)
  local out = {
    kind = "none",
    trees = {},
    floor = {},
    depth = 0,
    bounds = nil,
    treeBounds = nil,
    floorBounds = nil,
  }
  if not forestMode(state) then return out end

  local rects, bounds = worldRects(scenes)
  if not bounds or #rects == 0 then return out end

  depth = math.max(2, tonumber(depth) or DEFAULT_DEPTH)
  out.kind = "forest"
  out.depth = depth
  out.bounds = bounds
  out.treeBounds = {
    x0 = bounds.x0 - depth,
    y0 = bounds.y0 - depth,
    x1 = bounds.x1 + depth,
    y1 = bounds.y1 + depth,
  }
  out.floor, out.floorBounds = buildFloorRuns(rects, bounds)

  -- Sparse full-depth forest, then a second half-step pass only near the
  -- authoritative map boundary. The latter closes visible gaps between
  -- billboard canopies without multiplying the whole envelope cost.
  populateTreePass(out, rects, 0, depth + TREE_STEP * 0.8)
  populateTreePass(out, rects, 1, math.min(depth, INNER_BELT_DEPTH))

  return out
end

WorldEnvelope.DEFAULT_DEPTH = DEFAULT_DEPTH
WorldEnvelope.FLOOR_DEPTH = FLOOR_DEPTH
WorldEnvelope.FLOOR_Z = FLOOR_Z
WorldEnvelope.TREE_STEP = TREE_STEP
WorldEnvelope.INNER_BELT_DEPTH = INNER_BELT_DEPTH

return WorldEnvelope
