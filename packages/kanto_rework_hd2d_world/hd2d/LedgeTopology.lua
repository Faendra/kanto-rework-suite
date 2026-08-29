local LedgeTopology = {}

local CELL = 16
local STEP_WORLD = 0.24

-- Canonical Pokemon Red ledge rules from data/tilesets/ledge_tiles.asm.
-- A rule means: standing on `standing`, facing/input `dir`, with `ledge`
-- directly ahead => hop across the ledge and land one cell beyond it.
-- The standing side is therefore one logical terrain level above the landing
-- side. These are tile identities, never map-coordinate profiles.
local RULES = {
  { dir = "down",  standing = 0x2C, ledge = 0x37 },
  { dir = "down",  standing = 0x39, ledge = 0x36 },
  { dir = "down",  standing = 0x39, ledge = 0x37 },
  { dir = "left",  standing = 0x2C, ledge = 0x27 },
  { dir = "left",  standing = 0x39, ledge = 0x27 },
  { dir = "right", standing = 0x2C, ledge = 0x0D },
  { dir = "right", standing = 0x2C, ledge = 0x1D },
  { dir = "right", standing = 0x39, ledge = 0x0D },
}

local DELTA = {
  down = { 0, 1 }, up = { 0, -1 },
  left = { -1, 0 }, right = { 1, 0 },
}

local cache = setmetatable({}, { __mode = "k" })

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function smoothstep(t)
  t = clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end

local function inBounds(map, x, y)
  if not map then return false end
  if type(map.inBounds) == "function" then
    local ok, value = pcall(map.inBounds, map, x, y)
    if ok then return value == true end
  end
  return x >= 0 and y >= 0
     and x < (tonumber(map.widthCells) or 0)
     and y < (tonumber(map.heightCells) or 0)
end

local function cellTile(map, x, y)
  if not inBounds(map, x, y) or type(map.cellTile) ~= "function" then
    return nil
  end
  local ok, value = pcall(map.cellTile, map, x, y)
  return ok and value or nil
end

local function detectRule(map, cx, cy)
  if not (map and map.def and map.def.tileset == "OVERWORLD") then return nil end
  local front = cellTile(map, cx, cy)
  if front == nil then return nil end
  for _, rule in ipairs(RULES) do
    if front == rule.ledge then
      local d = DELTA[rule.dir]
      local sx, sy = cx - d[1], cy - d[2]
      if cellTile(map, sx, sy) == rule.standing then
        return rule
      end
    end
  end
  return nil
end

local function pointKey(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

local function build(map)
  local width = tonumber(map and map.widthCells) or 0
  local height = tonumber(map and map.heightCells) or 0
  local cells, byKey = {}, {}

  for y = 0, height - 1 do
    for x = 0, width - 1 do
      local rule = detectRule(map, x, y)
      if rule then
        local row = { x = x, y = y, dir = rule.dir, rule = rule }
        cells[#cells + 1] = row
        byKey[pointKey(x, y)] = row
      end
    end
  end

  local visited, segments = {}, {}
  for _, seed in ipairs(cells) do
    local sk = pointKey(seed.x, seed.y)
    if not visited[sk] then
      local segment = {
        dir = seed.dir,
        minX = seed.x, maxX = seed.x,
        minY = seed.y, maxY = seed.y,
        cells = {},
      }
      local queue = { seed }
      local qi = 1
      visited[sk] = true
      while queue[qi] do
        local cur = queue[qi]
        qi = qi + 1
        segment.cells[#segment.cells + 1] = cur
        segment.minX = math.min(segment.minX, cur.x)
        segment.maxX = math.max(segment.maxX, cur.x)
        segment.minY = math.min(segment.minY, cur.y)
        segment.maxY = math.max(segment.maxY, cur.y)

        local neighbours
        if cur.dir == "down" or cur.dir == "up" then
          neighbours = { { cur.x - 1, cur.y }, { cur.x + 1, cur.y } }
        else
          neighbours = { { cur.x, cur.y - 1 }, { cur.x, cur.y + 1 } }
        end
        for _, p in ipairs(neighbours) do
          local nk = pointKey(p[1], p[2])
          local other = byKey[nk]
          if other and other.dir == cur.dir and not visited[nk] then
            visited[nk] = true
            queue[#queue + 1] = other
          end
        end
      end
      segments[#segments + 1] = segment
    end
  end

  return { cells = cells, byKey = byKey, segments = segments }
end

local function topology(map)
  if not map then return { cells = {}, byKey = {}, segments = {} } end
  local cached = cache[map]
  if cached then return cached end
  cached = build(map)
  cache[map] = cached
  return cached
end

-- Each contiguous ledge segment contributes exactly one logical level on its
-- standing/high side. The influence is restricted to the segment's span so a
-- short ledge does not fabricate a full-map cliff. Stacked ledges accumulate.
function LedgeTopology.logicalLevel(map, cx, cy)
  local level = 0
  for _, seg in ipairs(topology(map).segments) do
    if seg.dir == "down" then
      if cx >= seg.minX and cx <= seg.maxX and cy <= seg.minY then
        level = level + 1
      end
    elseif seg.dir == "up" then
      if cx >= seg.minX and cx <= seg.maxX and cy >= seg.maxY then
        level = level + 1
      end
    elseif seg.dir == "left" then
      if cy >= seg.minY and cy <= seg.maxY and cx >= seg.maxX then
        level = level + 1
      end
    elseif seg.dir == "right" then
      if cy >= seg.minY and cy <= seg.maxY and cx <= seg.minX then
        level = level + 1
      end
    end
  end
  return level
end

function LedgeTopology.worldZ(map, cx, cy)
  return LedgeTopology.logicalLevel(map, cx, cy) * STEP_WORLD
end

function LedgeTopology.faceAt(map, cx, cy)
  local row = topology(map).byKey[pointKey(cx, cy)]
  if not row then return nil end
  local d = DELTA[row.dir]
  local lx, ly = cx + d[1], cy + d[2]
  local upperLevel = LedgeTopology.logicalLevel(map, cx, cy)
  local lowerLevel = LedgeTopology.logicalLevel(map, lx, ly)
  if lowerLevel >= upperLevel then lowerLevel = upperLevel - 1 end
  return {
    dir = row.dir,
    upperLevel = upperLevel,
    lowerLevel = lowerLevel,
    upperZ = upperLevel * STEP_WORLD,
    lowerZ = lowerLevel * STEP_WORLD,
  }
end

-- Player:pose() already supplies the vanilla sine hop as sprite lift. This
-- helper only smooths the TERRAIN baseline beneath that arc. A Gen I ledge
-- hop is exactly two cells: first step reaches the ledge tile while remaining
-- on the upper terrace, second step crosses the edge and lands one level down.
-- Keeping the baseline high for the first half and easing it down over the
-- second half prevents the renderer from snapping one full level when the
-- actor's feet first enter the landing cell.
function LedgeTopology.hopWorldZ(map, actor)
  if not (map and actor and actor.ledgeHop
          and type(actor.hopFrames) == "number"
          and type(actor.hopTotal) == "number"
          and actor.hopTotal > 0
          and type(actor.px) == "number"
          and type(actor.py) == "number") then
    return nil
  end

  local d = DELTA[actor.facing]
  if not d then return nil end

  local t = clamp(1 - actor.hopFrames / actor.hopTotal, 0, 1)
  -- Movement and hop counters advance on the same fixed 60 Hz update. Recover
  -- the original cell from the actor's interpolated 2-cell displacement; the
  -- rounding absorbs Player:update's integer-pixel quantisation.
  local travelled = 2 * CELL * t
  local startPx = actor.px - d[1] * travelled
  local startPy = actor.py - d[2] * travelled
  local startX = math.floor(startPx / CELL + 0.5)
  local startY = math.floor(startPy / CELL + 0.5)
  local landX = startX + d[1] * 2
  local landY = startY + d[2] * 2

  if not (inBounds(map, startX, startY) and inBounds(map, landX, landY)) then
    return nil
  end

  local highZ = LedgeTopology.worldZ(map, startX, startY)
  local lowZ = LedgeTopology.worldZ(map, landX, landY)
  if math.abs(highZ - lowZ) < 0.00001 then return nil end

  local descend = smoothstep((t - 0.5) * 2)
  return highZ + (lowZ - highZ) * descend, t, highZ, lowZ
end

function LedgeTopology.segments(map)
  return topology(map).segments
end

function LedgeTopology.invalidate(map)
  if map then cache[map] = nil else cache = setmetatable({}, { __mode = "k" }) end
end

LedgeTopology.RULES = RULES
LedgeTopology.STEP_WORLD = STEP_WORLD
LedgeTopology.CELL = CELL
LedgeTopology.DELTA = DELTA

return LedgeTopology
