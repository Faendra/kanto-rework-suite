local SemanticSceneBuilder = {}
SemanticSceneBuilder.__index = SemanticSceneBuilder

function SemanticSceneBuilder.new(RedHouseProfile)
  return setmetatable({
    RedHouseProfile = assert(RedHouseProfile, "SemanticSceneBuilder needs RedHouseProfile"),
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
      -- A semantic building owns its full footprint. The vanilla pixels in
      -- that footprint are material sources for the building and must not
      -- survive as a second, flattened copy on the ground plane.
      if not coveredByBuilding(buildings, x, y) then
        out[#out + 1] = { kind = "ground", x = x, y = y, z = 0 }
      end
    end
  end
  return out
end

function SemanticSceneBuilder:build(map)
  if not map then return nil end
  local key = sceneKey(map)
  if self.cache and self.cacheKey == key then return self.cache end

  local buildings = {}
  local redHouse = self.RedHouseProfile.detect(map)
  if redHouse then buildings[#buildings + 1] = redHouse end

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
