local LedgeTopology = {}

local CELL = 16
local STEP_WORLD = 0.24

-- Canonical Pokemon Red ledge rules from data/tilesets/ledge_tiles.asm.
-- These rules are authoritative for one-way hop semantics only. They do NOT
-- encode a global height-field for the rest of the map.
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

  -- Keep segment grouping for diagnostics and future authored elevation data,
  -- but never turn a segment into an infinite/semi-infinite map-wide level.
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
      local queue, qi = { seed }, 1
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

-- TEST11 originally inferred a global height-field by extending every ledge
-- segment to a map edge. Live footage proved that assumption invalid: small
-- ledges could raise unrelated streets and whole strips of a town. Gen1Recomp
-- exposes one-way hop rules, not persistent terrain elevation, so un-authored
-- terrain remains level zero. Explicit elevation APIs can still be consumed by
-- TerrainRemaster independently when they exist.
function LedgeTopology.logicalLevel(map, cx, cy)
  return 0
end

function LedgeTopology.worldZ(map, cx, cy)
  return 0
end

-- A canonical ledge still has one visual level of local relief. The lip itself
-- is rendered as a short atlas-textured face, but it no longer changes the Z of
-- arbitrary terrain, actors, buildings or vegetation elsewhere on the map.
function LedgeTopology.faceAt(map, cx, cy)
  local row = topology(map).byKey[pointKey(cx, cy)]
  if not row then return nil end
  return {
    dir = row.dir,
    upperLevel = 1,
    lowerLevel = 0,
    upperZ = STEP_WORLD,
    lowerZ = 0,
  }
end

-- Player:pose() already provides the canonical sine hop arc and Gen1Recomp's
-- movement controller owns the real two-cell landing. Without an authored
-- persistent height-field there is no safe extra baseline-Z transition to add.
function LedgeTopology.hopWorldZ(map, actor)
  return nil
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
