local Projection = dofile("packages/kanto_rework_hd2d_world/hd2d/SceneProjection.lua")
local Classifier = dofile("packages/kanto_rework_hd2d_world/hd2d/MaterialClassifier.lua")

local player = { px = 80, py = 64 }
local ctx = {
  width = 960,
  height = 540,
  vw = 160,
  vh = 144,
  cam = { x = 16, y = 8 },
  bgY = 8,
  state = { player = player },
}
local p = Projection.new(ctx, 2)
local ax, ay = p:cell(0, 0, 0)
local bx, by = p:cell(1, 0, 0)
local cx, cy = p:cell(0, 1, 0)
assert((bx - ax) * (cx - ax) < 0,
  "three-quarter camera must expose both world axes on opposite screen sides")
assert(by > ay and cy > ay,
  "positive world X/Y directions must move toward the camera in screen depth")

-- Perspective is now structural, not a post-process warp: one world-cell span
-- must visibly shrink with camera distance.
local nearY = p.targetY + 2
local farY = p.targetY - 5
local n0x = p:cell(p.targetX, nearY, 0)
local n1x = p:cell(p.targetX + 1, nearY, 0)
local f0x = p:cell(p.targetX, farY, 0)
local f1x = p:cell(p.targetX + 1, farY, 0)
assert(math.abs(f1x - f0x) < math.abs(n1x - n0x),
  "far ground cells must contract under perspective")

local gx, gy = p:cell(p.targetX, p.targetY, 0)
local hx, hy = p:cell(p.targetX, p.targetY, 1)
assert(hy < gy,
  "positive elevation must lift toward the top of the screen")
assert(math.abs(gx - hx) < 1e-6,
  "elevation on the camera target ray must not drift sideways")
assert(p.tileW > p.tileH and p.focal > 0,
  "perspective camera calibration is invalid")

local blocked = {}
for y = 2, 3 do
  for x = 2, 4 do blocked[y * 32 + x] = true end
end
local map = {
  def = { tileset = "OVERWORLD" },
  widthCells = 8,
  heightCells = 8,
  renderer = {},
}
function map:inBounds(x, y)
  return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
end
function map:isWaterCell() return false end
function map:isGrassCell() return false end
function map:isWarpTileCell(x, y) return x == 3 and y == 4 end
function map:warpAtCell(x, y)
  if self:isWarpTileCell(x, y) then return { index = 1 } end
  return nil
end
function map:isWalkableCell(x, y) return not blocked[y * 32 + x] end
function map:cellTile(x, y)
  if blocked[y * 32 + x] then return 0x30 + ((x + y) % 3) end
  return 0x01
end

local m = Classifier.classify(map, 3, 3)
assert(m.kind == "solid" and m.family == "structure",
  "compact warp-adjacent blocked mass must classify as architecture")
local mass = assert(Classifier.massInfo(map, 3, 3), "structure mass info missing")
assert(mass.spanX == 3 and mass.spanY == 2,
  "structure mass bounding geometry changed unexpectedly")

print("PASS hd2d_scene_contract")
