package.path = "./packages/kanto_rework_building_first/?.lua;./packages/kanto_rework_building_first/?/init.lua;" .. package.path

local RedProfile = dofile("packages/kanto_rework_building_first/building/PalletRedHouse.lua")
local RivalProfile = dofile("packages/kanto_rework_building_first/building/PalletRivalHouse.lua")
local OakProfile = dofile("packages/kanto_rework_building_first/building/PalletOakLab.lua")
local Builder = dofile("packages/kanto_rework_building_first/building/SemanticSceneBuilder.lua")
local WorldScene = dofile("packages/kanto_rework_building_first/building/WorldScene.lua")
local WorldEnvelope = dofile("packages/kanto_rework_building_first/building/WorldEnvelope.lua")

local function eq(actual, expected, label)
  if actual ~= expected then
    error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
  end
end

local function covers(outer, inner)
  return outer and inner
     and outer.x0 <= inner.x0 and outer.y0 <= inner.y0
     and outer.x1 >= inner.x1 and outer.y1 >= inner.y1
end

local image = {}
local map = {
  id = "PALLET_TOWN",
  def = { tileset = "OVERWORLD" },
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
eq(red.architecture.roofStyle, "hip", "Red roof style")
eq(rival.architecture.roofStyle, "hip", "Rival roof style")
eq(oak.architecture.roofStyle, "hip", "Oak roof style")

-- ARCHITECTURE-VOLUME-01: source projection masking, authored architecture
-- and visual occlusion are separate concepts. For the three Pallet buildings,
-- the observed masked depth is fully occupied by the reconstructed volume so
-- no sky/clear-canvas strip can survive behind the model.
for _, row in ipairs({
  { red, "Red", 4, 2, 8, 6 },
  { rival, "Rival", 12, 2, 16, 6 },
  { oak, "Oak", 10, 8, 16, 12 },
}) do
  local b, label = row[1], row[2]
  eq(b.groundClaim.x0, row[3], label .. " groundClaim x0")
  eq(b.groundClaim.y0, row[4], label .. " groundClaim y0")
  eq(b.groundClaim.x1, row[5], label .. " groundClaim x1")
  eq(b.groundClaim.y1, row[6], label .. " groundClaim y1")
  assert(b.architecture and b.architecture.footprint, label .. " architecture footprint missing")
  assert(b.occlusion and b.occlusion.footprint, label .. " occlusion footprint missing")
  assert(covers(b.architecture.footprint, b.groundClaim),
         label .. " architecture leaves part of masked vanilla projection uncovered")
  assert(covers(b.occlusion.footprint, b.architecture.footprint),
         label .. " occlusion volume does not cover architecture")
  eq(b.footprint, b.architecture.footprint,
     label .. " renderer compatibility footprint must alias authored architecture")
  eq(b.architecture.depth, 4.0, label .. " authored depth")
end

eq(red.architecture.ridgeY, 4.0, "Red centered ridge")
eq(rival.architecture.ridgeY, 4.0, "Rival centered ridge")
eq(oak.architecture.ridgeY, 10.0, "Oak centered ridge")
eq(oak.door.x, 12, "Oak door x")
eq(oak.door.y, 11, "Oak door y")
eq(red.architecture.ridgeInsetX, 1.0, "Red hip ridge inset")
eq(rival.architecture.ridgeInsetX, 1.0, "Rival hip ridge inset")
eq(oak.architecture.ridgeInsetX, 1.0, "Oak hip ridge inset")

-- VISUAL-SKIN-FIRERED-01: Red House uses semantic FireRed material slots while
-- Rival/Oak deliberately retain their Gen1 materials for the A/B prototype.
eq(red.visualSkin, "FIRERED_PALLET_HOUSE_V1", "Red visual skin")
eq(red.materials.roof.x0, "FIRERED:roof", "Red FireRed roof material")
eq(red.materials.roofLeft.x0, "FIRERED:roofLeft", "Red FireRed left roof material")
eq(red.materials.roofRight.x0, "FIRERED:roofRight", "Red FireRed right roof material")
eq(red.materials.facade.x0, "FIRERED:facade", "Red FireRed facade material")
eq(red.materials.side.x0, "FIRERED:side", "Red FireRed side material")
eq(red.materials.door.x, "FIRERED:door", "Red FireRed door material")
assert(rival.materials.roofLeft and rival.materials.roofRight,
       "Rival hip roof must expose authored side materials")
assert(type(rival.materials.roof.x0) == "number",
       "Rival must remain on Gen1 material source during FireRed A/B test")
assert(type(oak.materials.roof.x0) == "number",
       "Oak must remain on Gen1 material source during FireRed A/B test")

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
         "vanilla building projection leaked back into flat ground")
end
eq(builder.buildCount, 1, "initial semantic build")
local scene2 = builder:build(map)
assert(scene1 == scene2, "identical map/atlas must reuse prepared semantic scene")
eq(builder.buildCount, 1, "cache prevents per-frame semantic rebuild")

-- WORLD-ENVELOPE-01: the exterior is semantic object geometry, never one
-- giant projected fill plane. The forest belt must live outside gameplay map
-- rectangles and keep an actual connected neighbor rectangle clear.
local state = { map = map, neighbors = {} }
local scenes = WorldScene.collect(state)
local envelope = WorldEnvelope.build(state, scenes, 6)
eq(envelope.kind, "forest", "Pallet envelope kind")
assert(#envelope.trees > 0, "Pallet forest envelope is empty")
for _, tree in ipairs(envelope.trees) do
  assert(not (tree.x >= 0 and tree.x < 20 and tree.y >= 0 and tree.y < 18),
         "visual envelope tree entered authoritative Pallet gameplay rectangle")
end

local route = {
  id = "ROUTE_1", def = { tileset = "OVERWORLD" },
  widthCells = 20, heightCells = 12, renderer = { image = {} },
}
state.neighbors = { { map = route, ox = 0, oy = -12 * 16 } }
local connectedScenes = WorldScene.collect(state)
local connectedEnvelope = WorldEnvelope.build(state, connectedScenes, 6)
assert(#connectedEnvelope.trees > 0, "connected world lost forest envelope")
for _, tree in ipairs(connectedEnvelope.trees) do
  local inRoute = tree.x >= 0 and tree.x < 20 and tree.y >= -12 and tree.y < 0
  assert(not inRoute, "forest envelope blocked the real Route 1 connection")
end

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
assert(not source:find("drawFiller", 1, true), "obsolete giant planar filler returned")
assert(not source:find("worldFillTexture", 1, true), "renderer still depends on projected border-fill sheet")
assert(source:find("drawTreeCluster", 1, true), "semantic tree-cluster primitive missing")
assert(source:find('roofStyle == "hip"', 1, true), "generic hip-roof primitive missing")
for _, forbidden in ipairs({
  "SceneStyle", "LivePolish", "DioramaPolish", "NaturalForms", "NaturalScale",
  "AtlasWorld", "SceneContinuity", "TerrainRemaster", "LedgeTopology", "LedgeHopSmoothing",
}) do
  assert(not source:find(forbidden, 1, true), "building-first renderer imports forbidden historical layer: " .. forbidden)
end

local atlasHandle = assert(io.open("packages/kanto_rework_building_first/building/AtlasSource.lua", "rb"))
local atlasSource = atlasHandle:read("*a")
atlasHandle:close()
assert(atlasSource:find('FIRERED_PREFIX = "FIRERED:"', 1, true),
       "FireRed semantic material source missing")
assert(not atlasSource:find("newImageData", 1, true),
       "FireRed material source must not use GPU readback")

print(("BUILDING_FIRST_SEMANTIC_OK buildings=3 ground=304 depth=4 skin=FIRERED envelopeTrees=%d connectedTrees=%d")
  :format(#envelope.trees, #connectedEnvelope.trees))
