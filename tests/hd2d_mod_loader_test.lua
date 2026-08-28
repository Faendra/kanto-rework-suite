-- Headless compatibility gate for the parallel ChatGPT HD2D package against
-- the official Gen1Recomp mod loader. Run from a Gen1Recomp v0.2.32 checkout:
--
--   KRS_PACKAGE_DIR=/path/to/packages/kanto_rework_hd2d_world \
--     luajit /path/to/this/test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

-- Upstream's headless LOVE stub intentionally omits primitives that engine
-- logic does not need. Add only no-op geometry calls required by this renderer.
love.graphics.polygon = love.graphics.polygon or function() end
love.graphics.ellipse = love.graphics.ellipse or function() end
love.graphics.rectangle = love.graphics.rectangle or function() end

-- Real LÖVE Quads expose :setViewport; Gen1Recomp's headless stub only needs
-- immutable quads for its own tests and therefore omits that method. Preserve
-- the upstream constructor and add a no-op method solely to headless table
-- quads so our reusable-quad path can be exercised without pretending to
-- rasterize anything.
local upstreamNewQuad = love.graphics.newQuad
love.graphics.newQuad = function(...)
  local quad = upstreamNewQuad(...)
  if type(quad) == "table" and type(quad.setViewport) ~= "function" then
    quad.setViewport = function() end
  end
  return quad
end

local Loader = require("src.mods.Loader")
local Pipelines = require("src.render.Pipelines")

local packageDir = assert(os.getenv("KRS_PACKAGE_DIR"), "KRS_PACKAGE_DIR is required")
local RELATIVE_FILES = {
  "manifest.json",
  "main.lua",
  "hd2d/Projection.lua",
  "hd2d/MaterialClassifier.lua",
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
local ok = loader:load(data)
assert(ok, "KRS HD2D loader rejected package: " .. table.concat(loader.errors, "; "))
assert(#loader.errors == 0,
  "KRS HD2D produced loader errors: " .. table.concat(loader.errors, "; "))

local exports = assert(loader.exports.kanto_rework_hd2d_world,
  "KRS HD2D exports missing after load")
assert(type(exports.renderer) == "table", "renderer export missing")
assert(type(exports.projection) == "table", "projection export missing")
assert(type(exports.materialClassifier) == "table", "material classifier export missing")
assert(type(exports.relief) == "table", "relief export missing")
assert(type(exports.water) == "table", "water export missing")
assert(type(exports.occlusion) == "table", "occlusion export missing")
assert(type(exports.depthComposer) == "table", "depth composer export missing")

Pipelines.install(data)
local found
for _, row in ipairs(Pipelines.list()) do
  if row.id == "krs_hd2d_world" then found = row break end
end
assert(found, "krs_hd2d_world render pipeline was not registered")
assert(found.def and found.def.label == "KRS HD2D WORLD", "unexpected pipeline label")

Pipelines.setLevel("krs_hd2d_world", 1)
assert(Pipelines.worldPipeline() == "krs_hd2d_world",
  "enabled HD2D pipeline was not eligible")
local noWorld = Pipelines.drawWorld("krs_hd2d_world", {
  width = 320, height = 180, state = {},
})
assert(noWorld == nil, "no-overworld draw should fall back by returning nil")
assert(Pipelines.worldPipeline() == "krs_hd2d_world",
  "clean nil fallback must not retire the pipeline")

-- Synthetic read-only world: enough to exercise terrain capture, strip
-- projection, semantic relief, connected-neighbour capture, recessed water,
-- actor/terrain depth composition, warp-derived facade cues, contact planes,
-- airborne hops and grass foreground priority.
local drawCounts = { current = 0, neighbor = 0, fx = 0, grass = 0 }
local rendererStub = {
  drawBorderFill = function() drawCounts.current = drawCounts.current + 1 end,
  draw = function() drawCounts.current = drawCounts.current + 1 end,
  drawMapOnly = function() drawCounts.neighbor = drawCounts.neighbor + 1 end,
  drawCellBottom = function() drawCounts.grass = drawCounts.grass + 1 end,
}

local map = {
  id = "PALLET_TOWN",
  widthCells = 8,
  heightCells = 8,
  renderer = rendererStub,
  inBounds = function(_, x, y) return x >= 0 and y >= 0 and x < 8 and y < 8 end,
  isWaterCell = function(_, x, y) return y == 7 end,
  isGrassCell = function(_, x, y) return y == 5 and x >= 2 and x <= 4 end,
  isWarpTileCell = function(_, x, y) return x == 3 and y == 4 end,
  warpAtCell = function(_, x, y)
    if x == 3 and y == 4 then return { index = 1 } end
    return nil
  end,
  isWalkableCell = function(_, x, y)
    if y == 7 then return false end
    return not (y == 3 and x >= 2 and x <= 4)
  end,
}

local neighborMap = {
  id = "ROUTE_1",
  widthCells = 8,
  heightCells = 8,
  renderer = rendererStub,
  inBounds = function(_, x, y) return x >= 0 and y >= 0 and x < 8 and y < 8 end,
  isWaterCell = function() return false end,
  isGrassCell = function(_, x, y) return y == 4 and x >= 1 and x <= 3 end,
  isWarpTileCell = function() return false end,
  warpAtCell = function() return nil end,
  isWalkableCell = function(_, x, y)
    return not (x == 1 and y == 3)
  end,
}

local actorQuad = love.graphics.newQuad(0, 0, 16, 16, 16, 16)
local actorImage = love.graphics.newCanvas(16, 16)
local spriteStub = {
  getPoseGeometry = function()
    return { quad = actorQuad, width = 16, height = 16, anchorX = 8, anchorY = 16 }
  end,
  resolveImage = function() return actorImage end,
}
local function makeActor(id, cx, cy, opts)
  opts = opts or {}
  local actor = {
    id = id,
    cellX = cx, cellY = cy,
    px = cx * 16, py = cy * 16,
  }
  actor.pose = function(self)
    local poseY = self.py - (opts.hopLift or 0)
    return spriteStub, self.px, poseY, "down", 0, false, opts.hopping == true
  end
  return actor
end

local grassActor = makeActor("grass_probe", 3, 5)
local waterActor = makeActor("water_probe", 0, 7)
local hoppingActor = makeActor("hop_probe", 6, 2, { hopping = true, hopLift = 8 })
local state = {
  map = map,
  neighbors = { { map = neighborMap, ox = 64, oy = 0 } },
  entities = { grassActor, waterActor, hoppingActor }, ghosts = {},
  player = grassActor,
}

local rendered = Pipelines.drawWorld("krs_hd2d_world", {
  width = 640, height = 576,
  vw = 160, vh = 144,
  scale = 4,
  level = 1,
  state = state,
  cam = { x = 0, y = 0 },
  bgY = 0,
  paletteFor = function()
    return { {255,255,255}, {170,190,160}, {90,110,90}, {30,35,32} }
  end,
  drawFx = function(project, scale)
    local x, y = project(32, 32)
    assert(type(x) == "number" and type(y) == "number", "FX projection failed")
    assert(scale > 0, "FX projection scale invalid")
    drawCounts.fx = drawCounts.fx + 1
  end,
})

assert(rendered ~= nil, "synthetic HD2D world did not produce a canvas")
assert(drawCounts.current >= 2, "current map renderer was not captured")
assert(drawCounts.neighbor >= 1, "connected-neighbour renderer was not captured")
assert(exports.relief.lastScenes >= 2,
  "connected-neighbour semantic relief pass did not visit both scenes")
assert(exports.relief.lastCells >= 4,
  "connected-neighbour semantic relief did not classify all raised cells")
assert(exports.relief.lastTopRuns > 0,
  "continuous semantic top-surface pass did not draw any runs")
assert(exports.relief.lastTopRuns < exports.relief.lastCells,
  "contiguous raised cells were not merged into wider top-surface runs")
assert(exports.relief.lastDoorways >= 1,
  "real warp threshold did not produce a structure facade opening")
assert(exports.water.lastCells >= 8,
  "recessed water pass did not classify the synthetic water body")
assert(exports.water.lastRuns >= 1,
  "recessed water body was not emitted as a continuous source-texture run")
assert(exports.depthComposer.lastTerrainRows > 0,
  "terrain rows were not submitted to the unified depth composer")
assert(exports.depthComposer.lastActors == 3,
  "all synthetic actor billboards were not submitted to the depth composer")
assert(exports.depthComposer.lastWaterActors == 1,
  "water actor was not resolved onto the recessed contact plane")
assert(exports.depthComposer.lastHoppingActors == 1,
  "hopping actor was not tracked as airborne depth")
assert(exports.depthComposer.lastCommands
       == exports.depthComposer.lastTerrainRows + exports.depthComposer.lastActors,
  "depth composer command accounting is inconsistent")
assert(drawCounts.grass >= 1, "tall-grass cell-bottom occlusion did not execute")
assert(exports.occlusion.overlays >= 1,
  "tall-grass overlay was not composited at actor painter depth")
assert(drawCounts.fx == 1, "field FX bridge did not run exactly once")

Pipelines.reset()
Pipelines.install(nil)
Loader.endSession()
print("PASS hd2d_mod_loader_test")
