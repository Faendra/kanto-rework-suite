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

print("hd2d_projection_contract: ok")
