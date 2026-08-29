package.path = "./packages/kanto_rework_building_first/?.lua;./packages/kanto_rework_building_first/?/init.lua;" .. package.path

local RedProfile = dofile("packages/kanto_rework_building_first/building/PalletRedHouse.lua")
local RivalProfile = dofile("packages/kanto_rework_building_first/building/PalletRivalHouse.lua")
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
  return nil
end

local red = assert(RedProfile.detect(map), "Red house must be recognized from canonical warp")
local rival = assert(RivalProfile.detect(map), "Rival house must be recognized from canonical warp")

eq(red.semantic, "HOUSE", "Red semantic kind")
eq(rival.semantic, "HOUSE", "Rival semantic kind")
eq(red.family, "PALLET_HOUSE", "Red family")
eq(rival.family, "PALLET_HOUSE", "Rival family")
eq(red.footprint.x0, 4, "Red footprint x0")
eq(red.footprint.y0, 2, "Red footprint y0")
eq(red.footprint.x1, 8, "Red footprint x1 boundary")
eq(red.footprint.y1, 6, "Red footprint y1 boundary")
eq(red.door.x, 5, "Red door x")
eq(red.door.y, 5, "Red door y")
eq(rival.footprint.x0, 12, "Rival footprint x0")
eq(rival.footprint.y0, 2, "Rival footprint y0")
eq(rival.footprint.x1, 16, "Rival footprint x1 boundary")
eq(rival.footprint.y1, 6, "Rival footprint y1 boundary")
eq(rival.door.x, 13, "Rival door x")
eq(rival.door.y, 5, "Rival door y")

-- Both Pallet houses use the same vanilla 2x2 block motif, so they must share
-- an architectural family and proportions. Only semantic position/material
-- regions differ.
for _, key in ipairs({
  "wallHeight", "roofPeak", "roofThickness", "roofOverhang",
  "ridgeY", "doorHeight", "shadowInset",
}) do
  eq(rival.architecture[key], red.architecture[key], "shared Pallet house architecture " .. key)
end

local builder = Builder.new({ RedProfile, RivalProfile })
local scene1 = builder:build(map)
-- Pallet is 20x18 = 360 cells. Two disjoint 4x4 semantic footprints own 32
-- cells, leaving 328 ground cells and no flattened house copies.
eq(#scene1.ground, 328, "Pallet visible ground cell count")
eq(#scene1.buildings, 2, "semantic building count")
local seen = {}
for _, building in ipairs(scene1.buildings) do seen[building.id] = true end
assert(seen.PALLET_RED_HOUSE, "Red house missing from semantic scene")
assert(seen.PALLET_RIVAL_HOUSE, "Rival house missing from semantic scene")
for _, cell in ipairs(scene1.ground) do
  local inRed = cell.x >= 4 and cell.x < 8 and cell.y >= 2 and cell.y < 6
  local inRival = cell.x >= 12 and cell.x < 16 and cell.y >= 2 and cell.y < 6
  assert(not inRed and not inRival, "semantic building footprint leaked back into flat ground")
end
eq(builder.buildCount, 1, "initial semantic build")
local scene2 = builder:build(map)
assert(scene1 == scene2, "identical map/atlas must reuse prepared semantic scene")
eq(builder.buildCount, 1, "cache prevents per-frame semantic rebuild")

local wrongRed = {
  id = "PALLET_TOWN", widthCells = 20, heightCells = 18, renderer = { image = {} },
  warpAtCell = function(_, x, y)
    if x == 5 and y == 5 then return { def = { destMap = "BLUES_HOUSE" } } end
  end,
}
assert(RedProfile.detect(wrongRed) == nil, "wrong Red warp must not relabel a building")

local wrongRival = {
  id = "PALLET_TOWN", widthCells = 20, heightCells = 18, renderer = { image = {} },
  warpAtCell = function(_, x, y)
    if x == 13 and y == 5 then return { def = { destMap = "REDS_HOUSE_1F" } } end
  end,
}
assert(RivalProfile.detect(wrongRival) == nil, "wrong rival warp must not relabel a building")

local handle = assert(io.open("packages/kanto_rework_building_first/building/BuildingRenderer.lua", "rb"))
local source = handle:read("*a")
handle:close()
assert(not source:find("newImageData", 1, true), "renderer must not perform GPU readback")
assert(not source:find("PALLET_RIVAL_HOUSE", 1, true), "renderer contains rival-specific geometry")
assert(not source:find("BLUES_HOUSE", 1, true), "renderer contains rival-specific warp logic")
for _, forbidden in ipairs({
  "SceneStyle", "LivePolish", "DioramaPolish", "NaturalForms", "NaturalScale",
  "AtlasWorld", "SceneContinuity", "TerrainRemaster", "LedgeTopology", "LedgeHopSmoothing",
}) do
  assert(not source:find(forbidden, 1, true), "building-first renderer imports forbidden historical layer: " .. forbidden)
end

print("BUILDING_FIRST_SEMANTIC_OK buildings=2 ground=328")
