-- Official Gen1Recomp v0.2.32 loader gate for WORLD-ENVELOPE-01.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end
love.graphics.polygon = love.graphics.polygon or function() end
love.graphics.ellipse = love.graphics.ellipse or function() end
love.graphics.rectangle = love.graphics.rectangle or function() end

local Loader = require("src.mods.Loader")
local Pipelines = require("src.render.Pipelines")
local packageDir = assert(os.getenv("KRS_PACKAGE_DIR"), "KRS_PACKAGE_DIR is required")
local RELATIVE_FILES = {
  "manifest.json", "main.lua",
  "building/PalletRedHouse.lua", "building/PalletRivalHouse.lua", "building/PalletOakLab.lua",
  "building/SemanticSceneBuilder.lua", "building/WorldScene.lua", "building/WorldEnvelope.lua",
  "building/SceneProjection.lua", "building/AtlasSource.lua", "building/BuildingRenderer.lua",
}
local function readAll(path)
  local f = assert(io.open(path, "rb")); local v = f:read("*a"); f:close(); return v
end
local files, root = {}, "mods/kanto_rework_building_first"
for _, rel in ipairs(RELATIVE_FILES) do files[root .. "/" .. rel] = readAll(packageDir .. "/" .. rel) end
local function memfs(values)
  return {
    read = function(path) return values[path] end,
    getInfo = function(path)
      if values[path] then return { type = "file" } end
      local p = path .. "/"; for k in pairs(values) do if k:sub(1, #p) == p then return { type = "directory" } end end
    end,
    load = function(path) return values[path] and load(values[path], "@" .. path) or nil end,
    getDirectoryItems = function(path)
      local p = path == "" and "" or path .. "/"; local seen, out = {}, {}
      for k in pairs(values) do if k:sub(1, #p) == p then local c = k:sub(#p + 1):match("^[^/]+"); if c and not seen[c] then seen[c] = true; out[#out + 1] = c end end end
      table.sort(out); return out
    end,
    write = function(path, data) values[path] = data; return true end,
  }
end

local data = {}
local loader = Loader.new({ fs = memfs(files), generation = 1, dev = true })
assert(loader:load(data), table.concat(loader.errors, "; "))
assert(#loader.errors == 0, table.concat(loader.errors, "; "))
local exports = assert(loader.exports.kanto_rework_building_first)
for _, name in ipairs({ "renderer", "sceneBuilder", "worldScene", "worldEnvelope", "atlasSource" }) do
  assert(type(exports[name]) == "table", name .. " export missing")
end

Pipelines.install(data); Pipelines.setLevel("krs_building_first", 1); Pipelines.update(0)
assert(Pipelines.worldPipeline() == "krs_building_first")

local flatCalls = 0
local rendererStub = {
  draw = function() flatCalls = flatCalls + 1 end,
  drawMapOnly = function() flatCalls = flatCalls + 1 end,
  drawBorderFill = function() error("planar border fill must not be called") end,
}
rendererStub.image = love.graphics.newCanvas(128, 48)
rendererStub.quads = {}
for t = 0, 95 do rendererStub.quads[t] = love.graphics.newQuad((t % 16) * 8, math.floor(t / 16) * 8, 8, 8, 128, 48) end
local treeBlock = {}; for i = 1, 16 do treeBlock[i] = 0x2C + ((i - 1) % 4) end
local overworldTileset = { blocks = { [16] = treeBlock } }

local function tileAt(self, tx, ty)
  local cx, cy = math.floor(tx / 2), math.floor(ty / 2)
  if cx >= 4 and cx < 8 and cy >= 2 and cy < 6 then return 0x22 end
  if cx >= 12 and cx < 16 and cy >= 2 and cy < 6 then return 0x22 end
  if cx >= 10 and cx < 16 and cy >= 8 and cy < 12 then return 0x32 end
  return 0x2C
end
local function warpAt(self, x, y)
  if x == 5 and y == 5 then return { def = { destMap = "REDS_HOUSE_1F" } } end
  if x == 13 and y == 5 then return { def = { destMap = "BLUES_HOUSE" } } end
  if x == 12 and y == 11 then return { def = { destMap = "OAKS_LAB" } } end
end
local function makePallet()
  return { id = "PALLET_TOWN", def = { tileset = "OVERWORLD" }, tileset = overworldTileset,
           widthCells = 20, heightCells = 18, renderer = rendererStub,
           tileAt = tileAt, warpAtCell = warpAt }
end

local actorQuad = love.graphics.newQuad(0, 0, 16, 16, 16, 16)
local actorImage = love.graphics.newCanvas(16, 16)
local sprite = { getPoseGeometry = function() return { quad = actorQuad, width = 16, height = 16, anchorX = 8, anchorY = 16 } end,
                 resolveImage = function() return actorImage end }
local actor = { id = "RED", px = 160, py = 208 }
function actor:pose() return sprite, self.px, self.py, "down", 0, false, false end

local map = makePallet()
local state = { map = map, neighbors = {}, entities = { actor }, player = actor, ghosts = {} }
local ctx = { width = 640, height = 576, vw = 160, vh = 144, scale = 4, state = state,
              cam = { x = 0, y = 0 }, bgY = 0, drawFx = function() end }

assert(Pipelines.drawWorld("krs_building_first", ctx))
local m1 = exports.metrics()
assert(m1.groundCells == 304 and m1.buildings == 3 and m1.actors == 1)
assert(m1.worldScenes == 1 and m1.envelopeActive and m1.envelopeTrees > 0)
assert(m1.fillActive == false and flatCalls == 0)
local builds, trees = m1.materialBuilds, m1.envelopeTrees
assert(Pipelines.drawWorld("krs_building_first", ctx))
local m2 = exports.metrics()
assert(m2.materialBuilds == builds and m2.envelopeTrees == trees and m2.resourceResets == 0)

-- Save/map replacement must still invalidate GPU materials.
state.map = { id = "REDS_HOUSE_1F", def = { tileset = "HOUSE" }, widthCells = 20, heightCells = 18,
              renderer = rendererStub, tileAt = tileAt, warpAtCell = function() end }
assert(Pipelines.drawWorld("krs_building_first", ctx))
local mi = exports.metrics(); assert(mi.resourceResets == 1 and not mi.envelopeActive)
state.map = makePallet()
assert(Pipelines.drawWorld("krs_building_first", ctx))
local mr = exports.metrics(); assert(mr.resourceResets == 2 and mr.envelopeActive and mr.envelopeTrees > 0)

-- Connected Route 1 is authoritative world, so the envelope wraps the union.
local route1 = { id = "ROUTE_1", def = { tileset = "OVERWORLD" }, tileset = overworldTileset,
                 widthCells = 20, heightCells = 36, renderer = rendererStub,
                 tileAt = function() return 0x2C end, warpAtCell = function() end }
state.neighbors = { { map = route1, ox = 0, oy = -36 * 16 } }
assert(Pipelines.drawWorld("krs_building_first", ctx))
local mc = exports.metrics()
assert(mc.worldScenes == 2 and mc.groundCells == 304 + 720)
assert(mc.envelopeActive and mc.envelopeTrees > 0 and mc.fillActive == false)
assert(flatCalls == 0)

print(("PASS building_first_loader_v0232 scenes=%d trees=%d ground=%d resets=%d")
  :format(mc.worldScenes, mc.envelopeTrees, mc.groundCells, mc.resourceResets))
