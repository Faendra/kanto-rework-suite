local SemanticSceneBuilder = {}
SemanticSceneBuilder.__index = SemanticSceneBuilder

local function normalizeProfiles(profiles)
  assert(type(profiles) == "table", "SemanticSceneBuilder needs building profiles")
  if type(profiles.detect) == "function" then return { profiles } end

  local out = {}
  for i = 1, #profiles do
    local profile = profiles[i]
    assert(type(profile) == "table" and type(profile.detect) == "function",
           "SemanticSceneBuilder building profile #" .. tostring(i) .. " is invalid")
    out[#out + 1] = profile
  end
  assert(#out > 0, "SemanticSceneBuilder needs at least one building profile")
  return out
end

function SemanticSceneBuilder.new(BuildingProfiles)
  return setmetatable({
    BuildingProfiles = normalizeProfiles(BuildingProfiles),
    cacheKey = nil,
    cache = nil,
    buildCount = 0,
  }, SemanticSceneBuilder)
end

local function sceneKey(map)
  local renderer = map and map.renderer
  return table.concat({
    tostring(map),
    tostring(map and map.id),
    tostring(map and map.widthCells),
    tostring(map and map.heightCells),
    tostring(renderer and renderer.image),
  }, ":")
end

local function coveredByBuilding(buildings, x, y)
  for i = 1, #buildings do
    local f = buildings[i].footprint
    if f and x >= f.x0 and x < f.x1 and y >= f.y0 and y < f.y1 then
      return true
    end
  end
  return false
end

local function groundCells(map, buildings)
  local out = {}
  local w = math.max(0, math.floor(tonumber(map and map.widthCells) or 0))
  local h = math.max(0, math.floor(tonumber(map and map.heightCells) or 0))
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      -- Semantic structures own their footprints. Source pixels inside those
      -- footprints remain available as material input, but are not redrawn as
      -- a second flattened copy on the world ground.
      if not coveredByBuilding(buildings, x, y) then
        out[#out + 1] = { kind = "ground", x = x, y = y, z = 0 }
      end
    end
  end
  return out
end

local function detectBuildings(profiles, map)
  local buildings = {}
  local ids = {}
  for i = 1, #profiles do
    local building = profiles[i].detect(map)
    if building then
      local id = tostring(building.id or ("profile:" .. tostring(i)))
      assert(not ids[id], "duplicate semantic building id: " .. id)
      ids[id] = true
      buildings[#buildings + 1] = building
    end
  end
  return buildings
end

function SemanticSceneBuilder:build(map)
  if not map then return nil end
  local key = sceneKey(map)
  if self.cache and self.cacheKey == key then return self.cache end

  local buildings = detectBuildings(self.BuildingProfiles, map)
  self.cache = {
    key = key,
    map = map,
    ground = groundCells(map, buildings),
    buildings = buildings,
  }
  self.cacheKey = key
  self.buildCount = self.buildCount + 1
  return self.cache
end

function SemanticSceneBuilder:invalidate()
  self.cacheKey = nil
  self.cache = nil
end

return SemanticSceneBuilder
