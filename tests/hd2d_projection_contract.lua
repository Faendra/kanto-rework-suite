-- Pure contract checks for the parallel ChatGPT HD2D projection.
-- Run from the repository root with a Lua 5.1+/LuaJIT interpreter.
local Projection = dofile("packages/kanto_rework_hd2d_world/hd2d/Projection.lua")
local Classifier = dofile("packages/kanto_rework_hd2d_world/hd2d/MaterialClassifier.lua")

local function close(a, b, eps)
  return math.abs(a - b) <= (eps or 1e-6)
end

local function check(ok, message)
  if not ok then error(message, 0) end
end

local ctx = {
  vw = 160, vh = 144, width = 640, height = 576, scale = 4,
  cam = { x = 32, y = 48 }, bgY = 48,
}
local p = Projection.new(ctx, 2)

local far = p:depthScale(0)
local near = p:depthScale(144)
check(near > far, "near terrain must project wider than far terrain")

local x0, y0 = p:projectWorld(32 + 80, 48 + 72, 0)
local x1, y1 = p:projectWorld(32 + 80, 48 + 72, 8)
check(close(x0, x1), "height must not move the ground point horizontally")
check(y1 < y0, "positive relief must project upward")

local fake = {
  widthCells = 4, heightCells = 4,
  inBounds = function(_, x, y) return x >= 0 and y >= 0 and x < 4 and y < 4 end,
  isWaterCell = function(_, x, y) return x == 0 and y == 0 end,
  isGrassCell = function(_, x, y) return x == 1 and y == 0 end,
  isWalkableCell = function(_, x, y) return not (x == 2 and y == 0) end,
}
check(Classifier.classify(fake, 0, 0).kind == "water", "water classification")
check(Classifier.classify(fake, 1, 0).kind == "grass", "grass classification")
check(Classifier.classify(fake, 2, 0).kind == "solid", "solid classification")
check(Classifier.classify(fake, 3, 0).kind == "ground", "ground classification")
check(Classifier.frontExposed(fake, 2, 0), "solid front edge should extrude")

-- A connected blocked footprint beside a real warp threshold is promoted to
-- a structure family without any map-id or block-id profile. An isolated
-- blocked cell remains a low obstacle. These families are presentation-only.
local solid = {}
for y = 1, 2 do
  for x = 1, 3 do solid[y * 8 + x] = true end
end
solid[5 * 8 + 5] = true
local massMap = {
  widthCells = 6, heightCells = 6,
  renderer = {},
  inBounds = function(_, x, y) return x >= 0 and y >= 0 and x < 6 and y < 6 end,
  isWaterCell = function() return false end,
  isGrassCell = function() return false end,
  isWarpTileCell = function(_, x, y) return x == 2 and y == 3 end,
  warpAtCell = function(_, x, y)
    if x == 2 and y == 3 then return { index = 1 } end
    return nil
  end,
  isWalkableCell = function(_, x, y)
    if x == 2 and y == 3 then return true end
    return not solid[y * 8 + x]
  end,
}
local structure = Classifier.classify(massMap, 2, 2)
local obstacle = Classifier.classify(massMap, 5, 5)
check(structure.family == "structure", "warp-adjacent blocked mass should become structure")
check((structure.heightScale or 0) > 1,
  "structure should receive stronger visual relief than generic mass")
check(obstacle.family == "obstacle", "isolated blocked cell should remain low obstacle")
check(Classifier.reliefHeight(structure, 6) > Classifier.reliefHeight(obstacle, 6),
  "semantic families must create a visible but gameplay-neutral height hierarchy")

-- Natural OVERWORLD/FOREST maps may promote a repeated blocked motif into one
-- vegetation mass. The decision is derived from the runtime tileset and the
-- component's own repeated collision tile; no Pallet/block lookup is used.
local vegetationMap = {
  def = { tileset = "OVERWORLD" },
  widthCells = 6, heightCells = 6,
  renderer = {},
  inBounds = function(_, x, y) return x >= 0 and y >= 0 and x < 6 and y < 6 end,
  isWaterCell = function() return false end,
  isGrassCell = function() return false end,
  isWarpTileCell = function() return false end,
  warpAtCell = function() return nil end,
  isWalkableCell = function(_, x, y)
    return not (y <= 1 and x <= 4)
  end,
  cellTile = function(_, x, y)
    if y <= 1 and x <= 4 then return 0x52 end
    return 0x00
  end,
}
local vegetation = Classifier.classify(vegetationMap, 2, 1)
check(vegetation.family == "vegetation",
  "repeated natural blocked motif should become vegetation")
check((vegetation.heightScale or 0) > 1,
  "vegetation should receive a readable raised silhouette")

-- The same topology in a non-natural tileset must not silently become trees.
local cavernMap = {
  def = { tileset = "CAVERN" },
  widthCells = vegetationMap.widthCells, heightCells = vegetationMap.heightCells,
  renderer = {},
  inBounds = vegetationMap.inBounds,
  isWaterCell = vegetationMap.isWaterCell,
  isGrassCell = vegetationMap.isGrassCell,
  isWarpTileCell = vegetationMap.isWarpTileCell,
  warpAtCell = vegetationMap.warpAtCell,
  isWalkableCell = vegetationMap.isWalkableCell,
  cellTile = vegetationMap.cellTile,
}
check(Classifier.classify(cavernMap, 2, 1).family ~= "vegetation",
  "cavern boundary must not be promoted to vegetation")

print("hd2d_projection_contract: ok")
