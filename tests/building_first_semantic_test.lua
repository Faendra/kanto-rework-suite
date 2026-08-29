package.path = "./packages/kanto_rework_building_first/?.lua;./packages/kanto_rework_building_first/?/init.lua;" .. package.path

local Profile = dofile("packages/kanto_rework_building_first/building/PalletRedHouse.lua")
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
  return nil
end

local profile = Profile.detect(map)
assert(profile, "Red house must be recognized from PALLET_TOWN + canonical warp")
eq(profile.semantic, "HOUSE", "semantic kind")
eq(profile.footprint.x0, 4, "footprint x0")
eq(profile.footprint.y0, 2, "footprint y0")
eq(profile.footprint.x1, 8, "footprint x1 boundary")
eq(profile.footprint.y1, 6, "footprint y1 boundary")
eq(profile.door.x, 5, "door x")
eq(profile.door.y, 5, "door y")

local builder = Builder.new(Profile)
local scene1 = builder:build(map)
eq(#scene1.ground, 360, "Pallet ground cell count")
eq(#scene1.buildings, 1, "semantic building count")
eq(builder.buildCount, 1, "initial semantic build")
local scene2 = builder:build(map)
assert(scene1 == scene2, "identical map/atlas must reuse prepared semantic scene")
eq(builder.buildCount, 1, "cache prevents per-frame semantic rebuild")

local wrong = {
  id = "PALLET_TOWN", widthCells = 20, heightCells = 18, renderer = { image = {} },
  warpAtCell = function() return { def = { destMap = "BLUES_HOUSE" } } end,
}
assert(Profile.detect(wrong) == nil, "wrong warp destination must not be relabeled as Red's house")

local handle = assert(io.open("packages/kanto_rework_building_first/building/BuildingRenderer.lua", "rb"))
local source = handle:read("*a")
handle:close()
assert(not source:find("newImageData", 1, true), "renderer must not perform GPU readback")
for _, forbidden in ipairs({
  "SceneStyle", "LivePolish", "DioramaPolish", "NaturalForms", "NaturalScale",
  "AtlasWorld", "SceneContinuity", "TerrainRemaster", "LedgeTopology", "LedgeHopSmoothing",
}) do
  assert(not source:find(forbidden, 1, true), "building-first renderer imports forbidden historical layer: " .. forbidden)
end

print("BUILDING_FIRST_SEMANTIC_OK")
