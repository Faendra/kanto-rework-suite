local MaterialClassifier = {}

local MASS_CACHE = setmetatable({}, { __mode = "k" })
local DIRS = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }

-- These are the Gen I tilesets whose repeated blocked masses are most likely
-- vegetation rather than masonry. Structure detection still wins whenever a
-- real traversal threshold touches the mass, so houses in OVERWORLD maps do
-- not get promoted to trees.
local VEGETATION_TILESETS = {
  OVERWORLD = true,
  FOREST = true,
}

local function safeCall(object, method, ...)
  if not object or type(object[method]) ~= "function" then return nil end
  local ok, value = pcall(object[method], object, ...)
  if ok then return value end
  return nil
end

local function inBounds(map, cx, cy)
  local value = safeCall(map, "inBounds", cx, cy)
  if value ~= nil then return value end
  local w, h = tonumber(map and map.widthCells), tonumber(map and map.heightCells)
  return w and h and cx >= 0 and cy >= 0 and cx < w and cy < h or false
end

local function tilesetName(map)
  local def = map and map.def
  return def and def.tileset or nil
end

function MaterialClassifier.isTraversalThreshold(map, cx, cy)
  if not inBounds(map, cx, cy) then return false end
  return safeCall(map, "isWarpTileCell", cx, cy) == true
      or safeCall(map, "warpAtCell", cx, cy) ~= nil
end

-- Raw gameplay-derived material. This intentionally asks the Map object only
-- for read-only semantics and never infers traversal from the visual result.
local function rawKind(map, cx, cy)
  if not map or not inBounds(map, cx, cy) then return "void" end
  if safeCall(map, "isWaterCell", cx, cy) then return "water" end
  if safeCall(map, "isGrassCell", cx, cy) then return "grass" end

  -- A warp/door is a traversal threshold even when a tileset marks its
  -- collision tile unusually. Never raise a visual wall over a real exit.
  if MaterialClassifier.isTraversalThreshold(map, cx, cy) then
    return "ground"
  end

  if safeCall(map, "isWalkableCell", cx, cy) then return "ground" end
  return "solid"
end

local function cellKey(cx, cy, width)
  return cy * width + cx + 1
end

local function warpAdjacent(map, cx, cy)
  for _, d in ipairs(DIRS) do
    local nx, ny = cx + d[1], cy + d[2]
    if MaterialClassifier.isTraversalThreshold(map, nx, ny) then
      return true
    end
  end
  return false
end

local function familyFor(component, map)
  if component.warpEdges > 0 and component.size >= 3 then
    return "structure", 1.75
  end

  -- A repeated collision-tile signature inside a natural tileset is strong
  -- evidence for one repeated landscape motif (tree wall / forest mass).
  -- This stays data-derived: no map id or block id is authored here.
  if VEGETATION_TILESETS[tilesetName(map)] and component.size >= 4 then
    local repeatRatio = component.repeatRatio or 0
    if repeatRatio >= 0.45
       and (component.touchesEdge
            or (component.size >= 6 and (component.density or 0) >= 0.45)) then
      return "vegetation", 1.42
    end
  end

  if component.touchesEdge and component.size >= 4 then
    return "boundary", 1.28
  end
  if component.size <= 2 then
    return "obstacle", 0.72
  end

  if component.size >= 6 and (component.density or 0) >= 0.66 then
    return "landmark", 1.18
  end
  return "mass", 1.0
end

local function buildMassCache(map)
  local width = math.max(0, math.floor(tonumber(map and map.widthCells) or 0))
  local height = math.max(0, math.floor(tonumber(map and map.heightCells) or 0))
  local entry = {
    renderer = map and map.renderer or false,
    width = width,
    height = height,
    massAt = {},
    masses = {},
  }
  if width <= 0 or height <= 0 then return entry end

  local seen = {}
  local massId = 0
  for cy = 0, height - 1 do
    for cx = 0, width - 1 do
      local start = cellKey(cx, cy, width)
      if not seen[start] and rawKind(map, cx, cy) == "solid" then
        massId = massId + 1
        local component = {
          id = massId,
          size = 0,
          minX = cx, maxX = cx,
          minY = cy, maxY = cy,
          touchesEdge = false,
          warpEdges = 0,
          dominantTile = nil,
          dominantCount = 0,
          tileCounts = {},
          cells = {},
        }
        local queue = { {cx, cy} }
        local qi = 1
        seen[start] = true

        while queue[qi] do
          local pos = queue[qi]
          qi = qi + 1
          local x, y = pos[1], pos[2]
          local key = cellKey(x, y, width)
          component.size = component.size + 1
          component.cells[#component.cells + 1] = key
          if x < component.minX then component.minX = x end
          if x > component.maxX then component.maxX = x end
          if y < component.minY then component.minY = y end
          if y > component.maxY then component.maxY = y end
          if x == 0 or y == 0 or x == width - 1 or y == height - 1 then
            component.touchesEdge = true
          end
          if warpAdjacent(map, x, y) then
            component.warpEdges = component.warpEdges + 1
          end

          local tile = safeCall(map, "cellTile", x, y)
          if tile ~= nil then
            local count = (component.tileCounts[tile] or 0) + 1
            component.tileCounts[tile] = count
            if count > component.dominantCount then
              component.dominantTile = tile
              component.dominantCount = count
            end
          end

          for _, d in ipairs(DIRS) do
            local nx, ny = x + d[1], y + d[2]
            if nx >= 0 and ny >= 0 and nx < width and ny < height then
              local nk = cellKey(nx, ny, width)
              if not seen[nk] and rawKind(map, nx, ny) == "solid" then
                seen[nk] = true
                queue[#queue + 1] = {nx, ny}
              end
            end
          end
        end

        local spanX = component.maxX - component.minX + 1
        local spanY = component.maxY - component.minY + 1
        component.spanX = spanX
        component.spanY = spanY
        component.boxArea = math.max(1, spanX * spanY)
        component.density = component.size / component.boxArea
        component.repeatRatio = component.dominantCount / math.max(1, component.size)
        component.family, component.heightScale = familyFor(component, map)

        entry.masses[massId] = component
        for _, key in ipairs(component.cells) do
          entry.massAt[key] = component
        end
        component.cells = nil
        component.tileCounts = nil
      end
    end
  end
  return entry
end

local function massCache(map)
  if not map then return nil end
  local cached = MASS_CACHE[map]
  -- Gen1Recomp rebuilds a map renderer when its blocks change. Treat the
  -- renderer object as the visual-topology generation so Cut-style block
  -- mutations cannot leave stale semantic masses behind.
  local renderer = map.renderer or false
  local width = math.max(0, math.floor(tonumber(map.widthCells) or 0))
  local height = math.max(0, math.floor(tonumber(map.heightCells) or 0))
  if not cached or cached.renderer ~= renderer
     or cached.width ~= width or cached.height ~= height then
    cached = buildMassCache(map)
    MASS_CACHE[map] = cached
  end
  return cached
end

function MaterialClassifier.invalidate(map)
  if map then MASS_CACHE[map] = nil else MASS_CACHE = setmetatable({}, { __mode = "k" }) end
end

function MaterialClassifier.massInfo(map, cx, cy)
  if rawKind(map, cx, cy) ~= "solid" then return nil end
  local cache = massCache(map)
  if not cache or cache.width <= 0 then return nil end
  return cache.massAt[cellKey(cx, cy, cache.width)]
end

function MaterialClassifier.classify(map, cx, cy)
  local kind = rawKind(map, cx, cy)
  if kind == "void" then return { kind = "void", height = 0 } end
  if kind == "water" then return { kind = "water", height = -1 } end
  if kind == "grass" then return { kind = "grass", height = 0 } end
  if kind == "ground" then return { kind = "ground", height = 0 } end

  -- Solid cells are grouped into continuous semantic masses. Geometry is
  -- still derived entirely from gameplay/map evidence; the family only
  -- changes visual height/readability and never feeds collision back.
  local mass = MaterialClassifier.massInfo(map, cx, cy)
  return {
    kind = "solid",
    height = 1,
    family = mass and mass.family or "mass",
    massId = mass and mass.id or nil,
    heightScale = mass and mass.heightScale or 1,
  }
end

function MaterialClassifier.reliefHeight(material, baseLift)
  if not material then return 0 end
  if material.kind == "solid" then
    return (baseLift or 6) * (material.heightScale or 1)
  end
  if material.kind == "water" then return -1 end
  return 0
end

function MaterialClassifier.frontExposed(map, cx, cy)
  local here = MaterialClassifier.classify(map, cx, cy)
  if here.kind ~= "solid" then return false end
  local front = MaterialClassifier.classify(map, cx, cy + 1)
  return front.kind ~= "solid"
end

function MaterialClassifier.sideExposed(map, cx, cy, dx)
  local here = MaterialClassifier.classify(map, cx, cy)
  if here.kind ~= "solid" then return false end
  local side = MaterialClassifier.classify(map, cx + dx, cy)
  return side.kind ~= "solid"
end

return MaterialClassifier
