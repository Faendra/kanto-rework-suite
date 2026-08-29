package.path = "./packages/kanto_rework_building_first/?.lua;./packages/kanto_rework_building_first/?/init.lua;" .. package.path

local RedProfile = dofile("packages/kanto_rework_building_first/building/PalletRedHouse.lua")
local RivalProfile = dofile("packages/kanto_rework_building_first/building/PalletRivalHouse.lua")
local OakProfile = dofile("packages/kanto_rework_building_first/building/PalletOakLab.lua")
local Builder = dofile("packages/kanto_rework_building_first/building/SemanticSceneBuilder.lua")

local function eq(actual, expected, label)
  if actual ~= expected then
    error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
  end
end

local image = {}
local map = {
  id = "PALLET_TOWN",
  widthCells = 20,
  heightCells = 18,
  renderer = { image = image },
}
function map:warpAtCell(x, y)
  if x == 5 and y == 5 then return { def = { destMap = "REDS_HOUSE_1F", destWarp = 1 } } end
  if x == 13 and y == 5 then return { def = { destMap = "BLUES_HOUSE", destWarp = 1 } } end
  if x == 12 and y == 11 then return { def = { destMap = "OAKS_LAB", destWarp = 2 } } end
  return nil
end

local red = assert(RedProfile.detect(map), "Red house must be recognized from canonical warp")
local rival = assert(RivalProfile.detect(map), "Rival house must be recognized from canonical warp")
local oak = assert(OakProfile.detect(map), "Oak lab must be recognized from canonical warp")

eq(red.semantic, "HOUSE", "Red semantic kind")
eq(rival.semantic, "HOUSE", "Rival semantic kind")
eq(oak.semantic, "LAB", "Oak semantic kind")
eq(red.family, "PALLET_HOUSE", "Red family")
eq(rival.family, "PALLET_HOUSE", "Rival family")
eq(oak.family, "PALLET_LAB", "Oak family")
eq(red.architecture.roofStyle, "gable", "Red roof style")
eq(rival.architecture.roofStyle, "gable", "Rival roof style")
eq(oak.architecture.roofStyle, "hip", "Oak roof style")

eq(red.footprint.x0, 4, "Red footprint x0")
eq(red.footprint.y0, 2, "Red footprint y0")
eq(red.footprint.x1, 8, "Red footprint x1 boundary")
eq(red.footprint.y1, 6, "Red footprint y1 boundary")
eq(rival.footprint.x0, 12, "Rival footprint x0")
eq(rival.footprint.y0, 2, "Rival footprint y0")
eq(rival.footprint.x1, 16, "Rival footprint x1 boundary")
eq(rival.footprint.y1, 6, "Rival footprint y1 boundary")
eq(oak.footprint.x0, 10, "Oak footprint x0")
eq(oak.footprint.y0, 8, "Oak footprint y0")
eq(oak.footprint.x1, 16, "Oak footprint x1 boundary")
eq(oak.footprint.y1, 12, "Oak footprint y1 boundary")
eq(oak.door.x, 12, "Oak door x")
eq(oak.door.y, 11, "Oak door y")
eq(oak.architecture.ridgeInsetX, 1.0, "Oak hip ridge inset")

for _, key in ipairs({
  "wallHeight", "roofPeak", "roofThickness", "roofOverhang",
  "doorHeight", "shadowInset",
}) do
  eq(rival.architecture[key], red.architecture[key], "shared Pallet house architecture " .. key)
  eq(oak.architecture[key], red.architecture[key], "shared Pallet scale " .. key)
end

local builder = Builder.new({ RedProfile, RivalProfile, OakProfile })
local scene1 = builder:build(map)
eq(#scene1.ground, 304, "Pallet visible ground cell count")
eq(#scene1.buildings, 3, "semantic building count")
local seen = {}
for _, building in ipairs(scene1.buildings) do seen[building.id] = true end
assert(seen.PALLET_RED_HOUSE, "Red house missing from semantic scene")
assert(seen.PALLET_RIVAL_HOUSE, "Rival house missing from semantic scene")
assert(seen.PALLET_OAK_LAB, "Oak lab missing from semantic scene")
for _, cell in ipairs(scene1.ground) do
  local inRed = cell.x >= 4 and cell.x < 8 and cell.y >= 2 and cell.y < 6
  local inRival = cell.x >= 12 and cell.x < 16 and cell.y >= 2 and cell.y < 6
  local inOak = cell.x >= 10 and cell.x < 16 and cell.y >= 8 and cell.y < 12
  assert(not inRed and not inRival and not inOak,
         "semantic building footprint leaked back into flat ground")
end
eq(builder.buildCount, 1, "initial semantic build")
local scene2 = builder:build(map)
assert(scene1 == scene2, "identical map/atlas must reuse prepared semantic scene")
eq(builder.buildCount, 1, "cache prevents per-frame semantic rebuild")

local wrongOak = {
  id = "PALLET_TOWN", widthCells = 20, heightCells = 18, renderer = { image = {} },
  warpAtCell = function(_, x, y)
    if x == 12 and y == 11 then return { def = { destMap = "BLUES_HOUSE" } } end
  end,
}
assert(OakProfile.detect(wrongOak) == nil, "wrong Oak warp must not relabel a building")

local handle = assert(io.open("packages/kanto_rework_building_first/building/BuildingRenderer.lua", "rb"))
local source = handle:read("*a")
handle:close()
assert(not source:find("newImageData", 1, true), "renderer must not perform GPU readback")
assert(not source:find("PALLET_RIVAL_HOUSE", 1, true), "renderer contains rival-specific geometry")
assert(not source:find("PALLET_OAK_LAB", 1, true), "renderer contains Oak-specific geometry")
assert(not source:find("BLUES_HOUSE", 1, true), "renderer contains rival-specific warp logic")
assert(not source:find("OAKS_LAB", 1, true), "renderer contains Oak-specific warp logic")
assert(source:find('roofStyle == "hip"', 1, true), "generic hip-roof primitive missing")
for _, forbidden in ipairs({
  "SceneStyle", "LivePolish", "DioramaPolish", "NaturalForms", "NaturalScale",
  "AtlasWorld", "SceneContinuity", "TerrainRemaster", "LedgeTopology", "LedgeHopSmoothing",
}) do
  assert(not source:find(forbidden, 1, true), "building-first renderer imports forbidden historical layer: " .. forbidden)
end

print("BUILDING_FIRST_SEMANTIC_OK buildings=3 ground=304 roofStyles=gable,hip")
