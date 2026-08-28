-- Official Gen1Recomp v0.2.32 loader gate for the scene-graph HD2D renderer.
-- Run from a Gen1Recomp checkout with KRS_PACKAGE_DIR pointing at the package.

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

love.graphics.polygon = love.graphics.polygon or function() end
love.graphics.ellipse = love.graphics.ellipse or function() end
love.graphics.rectangle = love.graphics.rectangle or function() end
love.graphics.line = love.graphics.line or function() end
love.graphics.setLineWidth = love.graphics.setLineWidth or function() end

local upstreamNewQuad = love.graphics.newQuad
if upstreamNewQuad then
  love.graphics.newQuad = function(...)
    local quad = upstreamNewQuad(...)
    if type(quad) == "table" and type(quad.setViewport) ~= "function" then
      quad.setViewport = function() end
    end
    return quad
  end
end

local Loader = require("src.mods.Loader")
local Pipelines = require("src.render.Pipelines")
local packageDir = assert(os.getenv("KRS_PACKAGE_DIR"), "KRS_PACKAGE_DIR is required")

local RELATIVE_FILES = {
  "manifest.json",
  "main.lua",
  "hd2d/SceneProjection.lua",
  "hd2d/SceneRenderer.lua",
  "hd2d/MaterialClassifier.lua",
  "hd2d/WorldAtmosphere.lua",
  -- Transitional compatibility exports still loaded by main.lua.
  "hd2d/Projection.lua",
  "hd2d/Relief.lua",
  "hd2d/WaterSurface.lua",
  "hd2d/Occlusion.lua",
  "hd2d/DepthComposer.lua",
  "hd2d/Renderer.lua",
}

local function readAll(path)
  local f, err = io.open(path, "rb")
  assert(f, err)
  local value = f:read("*a")
  f:close()
  return value
end

local files = {}
local root = "mods/kanto_rework_hd2d_world"
for _, rel in ipairs(RELATIVE_FILES) do
  files[root .. "/" .. rel] = readAll(packageDir .. "/" .. rel)
end

local function memfs(values)
  return {
    read = function(path) return values[path] end,
    getInfo = function(path)
      if values[path] then return { type = "file" } end
      local prefix = path .. "/"
      for key in pairs(values) do
        if key:sub(1, #prefix) == prefix then return { type = "directory" } end
      end
      return nil
    end,
    load = function(path)
      if not values[path] then return nil, "no file: " .. path end
      return load(values[path], "@" .. path)
    end,
    getDirectoryItems = function(path)
      local prefix = path == "" and "" or (path .. "/")
      local seen, out = {}, {}
      for key in pairs(values) do
        if key:sub(1, #prefix) == prefix then
          local child = key:sub(#prefix + 1):match("^[^/]+")
          if child and child ~= "" and not seen[child] then
            seen[child] = true
            out[#out + 1] = child
          end
        end
      end
      table.sort(out)
      return out
    end,
    write = function(path, data)
      values[path] = data
      return true
    end,
  }
end

local data = {}
local loader = Loader.new({ fs = memfs(files), generation = 1, dev = true })
assert(loader:load(data),
  "scene HD2D loader rejected package: " .. table.concat(loader.errors, "; "))
assert(#loader.errors == 0,
  "scene HD2D loader errors: " .. table.concat(loader.errors, "; "))

local exports = assert(loader.exports.kanto_rework_hd2d_world,
  "scene HD2D exports missing")
assert(type(exports.renderer) == "table", "scene renderer export missing")
assert(type(exports.projection) == "table", "scene projection export missing")
assert(type(exports.materialClassifier) == "table", "material classifier export missing")
assert(type(exports.atmosphere) == "table", "atmosphere export missing")

Pipelines.install(data)
local found
for _, row in ipairs(Pipelines.list()) do
  if row.id == "krs_hd2d_world" then found = row break end
end
assert(found and found.def and found.def.label == "KRS HD2D WORLD",
  "scene HD2D pipeline was not registered")

Pipelines.setLevel("krs_hd2d_world", 2)
Pipelines.update(0)
assert(Pipelines.worldPipeline() == "krs_hd2d_world",
  "scene HD2D pipeline was not eligible")

local noWorld = Pipelines.drawWorld("krs_hd2d_world", {
  width = 640, height = 576, state = {},
})
assert(noWorld == nil, "incomplete world should cleanly fall back")

local drawCounts = { current = 0, neighbor = 0, fx = 0 }
local rendererStub = {
  drawBorderFill = function() drawCounts.current = drawCounts.current + 1 end,
  draw = function() drawCounts.current = drawCounts.current + 1 end,
  drawMapOnly = function() drawCounts.neighbor = drawCounts.neighbor + 1 end,
  drawCellBottom = function() end,
}

local blocked = {}
for y = 2, 3 do
  for x = 2, 4 do blocked[y * 32 + x] = "structure" end
end
for y = 0, 3 do
  for x = 7, 8 do blocked[y * 32 + x] = "vegetation" end
end

local map = {
  id = "SYNTHETIC_PALLET",
  def = { tileset = "OVERWORLD" },
  widthCells = 10,
  heightCells = 9,
  renderer = rendererStub,
}
function map:inBounds(x, y)
  return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
end
function map:isWaterCell(x, y) return y == 8 end
function map:isGrassCell(x, y) return y == 6 and x >= 4 and x <= 6 end
function map:isWarpTileCell(x, y) return x == 3 and y == 4 end
function map:warpAtCell(x, y)
  if self:isWarpTileCell(x, y) then return { index = 1 } end
  return nil
end
function map:isWalkableCell(x, y)
  if self:isWaterCell(x, y) then return false end
  return blocked[y * 32 + x] == nil
end
function map:cellTile(x, y)
  local kind = blocked[y * 32 + x]
  if kind == "vegetation" then return 0x52 end
  if kind == "structure" then return 0x30 + ((x + y) % 3) end
  if self:isWaterCell(x, y) then return 0x14 end
  return 0x01
end

local neighborMap = {
  id = "SYNTHETIC_ROUTE",
  def = { tileset = "OVERWORLD" },
  widthCells = 8,
  heightCells = 8,
  renderer = rendererStub,
}
function neighborMap:inBounds(x, y)
  return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
end
function neighborMap:isWaterCell() return false end
function neighborMap:isGrassCell(x, y) return y == 3 and x >= 2 and x <= 4 end
function neighborMap:isWarpTileCell() return false end
function neighborMap:warpAtCell() return nil end
function neighborMap:isWalkableCell(x, y) return not (y <= 1 and x <= 4) end
function neighborMap:cellTile(x, y)
  if y <= 1 and x <= 4 then return 0x52 end
  return 0x01
end

local actorQuad = love.graphics.newQuad(0, 0, 16, 16, 16, 16)
local actorImage = love.graphics.newCanvas(16, 16)
local spriteStub = {
  getPoseGeometry = function()
    return { quad = actorQuad, width = 16, height = 16, anchorX = 8, anchorY = 16 }
  end,
  resolveImage = function() return actorImage end,
}
local actor = { id = "RED", px = 5 * 16, py = 5 * 16 }
function actor:pose()
  return spriteStub, self.px, self.py, "down", 0, false, false
end

local state = {
  map = map,
  neighbors = { { map = neighborMap, ox = 10 * 16, oy = 0 } },
  entities = { actor },
  ghosts = {},
  player = actor,
}

local worldCtx = {
  width = 640, height = 576,
  vw = 160, vh = 144,
  scale = 4,
  level = 2,
  state = state,
  cam = { x = 0, y = 0 },
  bgY = 0,
  paletteFor = function()
    return { {255,255,255}, {170,190,160}, {90,110,90}, {30,35,32} }
  end,
  drawFx = function(project, scale)
    local x, y = project(actor.px + 8, actor.py + 12)
    assert(type(x) == "number" and type(y) == "number", "scene FX projection failed")
    assert(scale > 0, "scene FX scale invalid")
    drawCounts.fx = drawCounts.fx + 1
  end,
}

local proj = exports.projection.new(worldCtx, 2)
local ax, ay = proj:cell(0, 0, 0)
local bx, by = proj:cell(1, 0, 0)
local cx, cy = proj:cell(0, 1, 0)
assert((bx - ax) * (cx - ax) < 0,
  "world axes do not rotate in opposite X directions; projection regressed to a flat trapezoid")
assert(by > ay and cy > ay,
  "both world axes must recede downward in the isometric camera")

local rendered = Pipelines.drawWorld("krs_hd2d_world", worldCtx)
assert(rendered ~= nil, "scene renderer produced no canvas")
assert(exports.renderer.lastGroundCells >= 40,
  "scene renderer did not emit a shared ground plane")
assert(exports.renderer.lastStructures >= 1,
  "warp-derived building was not emitted as one scene volume")
assert(exports.renderer.lastVegetation >= 1,
  "vegetation did not become scene objects")
assert(exports.renderer.lastActors == 1,
  "upright actor billboard was not depth composed")
assert(exports.renderer.lastWaterCells >= 1,
  "water contact plane was not emitted")
assert(exports.renderer.lastCommands >= 3,
  "scene graph contained too few depth-sorted commands")
assert(drawCounts.current >= 2,
  "current map renderer was not captured for terrain texturing")
assert(drawCounts.neighbor >= 1,
  "connected map renderer was not captured")
assert(drawCounts.fx == 1 and exports.renderer.lastFx == 1,
  "field FX bridge did not run through scene projection")

local presented = Pipelines.worldPresent(rendered, worldCtx)
assert(presented == rendered,
  "headless atmosphere fallback should preserve scene canvas")
assert(exports.atmosphere.lastBypassed == true,
  "headless atmosphere path did not report clean bypass")
assert(Pipelines.worldPipeline() == "krs_hd2d_world",
  "headless atmosphere bypass retired the pipeline")

Pipelines.reset()
Pipelines.install(nil)
Loader.endSession()
print("PASS hd2d_scene_loader_test")
