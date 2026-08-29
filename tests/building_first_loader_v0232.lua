-- Official Gen1Recomp v0.2.32 loader gate for BUILDING-03.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

love.graphics.polygon = love.graphics.polygon or function() end
love.graphics.ellipse = love.graphics.ellipse or function() end
love.graphics.rectangle = love.graphics.rectangle or function() end

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
  "manifest.json", "main.lua",
  "building/PalletRedHouse.lua",
  "building/PalletRivalHouse.lua",
  "building/PalletOakLab.lua",
  "building/SemanticSceneBuilder.lua",
  "building/SceneProjection.lua",
  "building/AtlasSource.lua",
  "building/BuildingRenderer.lua",
}

local function readAll(path)
  local f, err = io.open(path, "rb")
  assert(f, err)
  local value = f:read("*a")
  f:close()
  return value
end

local files, root = {}, "mods/kanto_rework_building_first"
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
            seen[child], out[#out + 1] = true, child
          end
        end
      end
      table.sort(out)
      return out
    end,
    write = function(path, data) values[path] = data return true end,
  }
end

local data = {}
local loader = Loader.new({ fs = memfs(files), generation = 1, dev = true })
assert(loader:load(data), "BUILDING-03 loader rejected package: " .. table.concat(loader.errors, "; "))
assert(#loader.errors == 0, "BUILDING-03 loader errors: " .. table.concat(loader.errors, "; "))

local exports = assert(loader.exports.kanto_rework_building_first, "BUILDING-03 exports missing")
for _, name in ipairs({
  "renderer", "sceneBuilder", "buildingProfiles", "redHouseProfile",
  "rivalHouseProfile", "oakLabProfile", "projection", "atlasSource",
}) do
  assert(type(exports[name]) == "table", name .. " export missing")
end
assert(#exports.buildingProfiles == 3, "expected three Pallet building profiles")
assert(type(exports.metrics) == "function", "metrics export missing")

Pipelines.install(data)
Pipelines.setLevel("krs_building_first", 1)
Pipelines.update(0)
assert(Pipelines.worldPipeline() == "krs_building_first", "BUILDING-03 pipeline unavailable")

local flatCalls = 0
local rendererStub = {
  draw = function() flatCalls = flatCalls + 1 end,
  drawMapOnly = function() flatCalls = flatCalls + 1 end,
  drawBorderFill = function() flatCalls = flatCalls + 1 end,
}
rendererStub.image = love.graphics.newCanvas(128, 48)
rendererStub.quads = {}
for t = 0, 95 do
  rendererStub.quads[t] = love.graphics.newQuad((t % 16) * 8,
                                                math.floor(t / 16) * 8,
                                                8, 8, 128, 48)
end

local W, H = 20, 18
local map = { id = "PALLET_TOWN", def = { tileset = "OVERWORLD" },
              widthCells = W, heightCells = H, renderer = rendererStub }
function map:warpAtCell(x, y)
  if x == 5 and y == 5 then
    return { index = 1, def = { destMap = "REDS_HOUSE_1F", destWarp = 1 } }
  end
  if x == 13 and y == 5 then
    return { index = 2, def = { destMap = "BLUES_HOUSE", destWarp = 1 } }
  end
  if x == 12 and y == 11 then
    return { index = 3, def = { destMap = "OAKS_LAB", destWarp = 2 } }
  end
  return nil
end

local function inHouse(cx, cy, x0)
  return cx >= x0 and cx <= x0 + 3 and cy >= 2 and cy <= 5
end

function map:tileAt(tx, ty)
  local cx, cy = math.floor(tx / 2), math.floor(ty / 2)
  local q = (ty % 2) * 2 + (tx % 2)
  local inRed = inHouse(cx, cy, 4)
  local inRival = inHouse(cx, cy, 12)
  if (inRed or inRival) and cy <= 3 then return 0x22 end
  if (inRed or inRival) and cy >= 4 then
    if (cx == 5 or cx == 13) and cy == 5 then return 0x1D end
    return 0x30
  end

  local inOak = cx >= 10 and cx <= 15 and cy >= 8 and cy <= 11
  if inOak and cy <= 9 then
    if cx == 10 or cx == 15 then return 0x36 + q end
    return 0x32 + q
  end
  if inOak and cy >= 10 then
    if cx == 12 and cy == 11 then return 0x40 end
    return 0x3C + q
  end
  return 0x2C
end

local actorQuad = love.graphics.newQuad(0, 0, 16, 16, 16, 16)
local actorImage = love.graphics.newCanvas(16, 16)
local sprite = {
  getPoseGeometry = function()
    return { quad = actorQuad, width = 16, height = 16, anchorX = 8, anchorY = 16 }
  end,
  resolveImage = function() return actorImage end,
}
local actor = { id = "RED", px = 10 * 16, py = 13 * 16 }
function actor:pose() return sprite, self.px, self.py, "down", 0, false, false end

local state = { map = map, neighbors = {}, entities = { actor }, ghosts = {}, player = actor }
local ctx = {
  width = 640, height = 576, vw = 160, vh = 144, scale = 4,
  state = state, cam = { x = 0, y = 0 }, bgY = 0,
  drawFx = function() end,
}

local before = {
  mapId = map.id,
  px = actor.px,
  py = actor.py,
  redWarp = map:warpAtCell(5, 5).def.destMap,
  rivalWarp = map:warpAtCell(13, 5).def.destMap,
  oakWarp = map:warpAtCell(12, 11).def.destMap,
}
local rendered = Pipelines.drawWorld("krs_building_first", ctx)
assert(rendered ~= nil, "BUILDING-03 renderer produced no canvas")
local m1 = exports.metrics()
assert(m1.semanticBuilds == 1, "semantic scene was not prepared exactly once")
assert(m1.groundCells == 304, "three semantic footprints were not removed from flat Pallet ground")
assert(m1.buildings == 3, "Pallet semantic buildings missing")
assert(m1.actors == 1, "Red actor billboard missing")
assert(m1.materialBuilds > 0, "runtime atlas materials were not cached")
assert(flatCalls == 0, "building-first path invoked flattened map drawing")

local materialBuilds = m1.materialBuilds
local rendered2 = Pipelines.drawWorld("krs_building_first", ctx)
assert(rendered2 ~= nil, "second BUILDING-03 draw failed")
local m2 = exports.metrics()
assert(m2.semanticBuilds == 1, "semantic scene rebuilt during stable draw")
assert(m2.materialBuilds == materialBuilds, "atlas materials rebuilt during stable draw")
assert(map.id == before.mapId and actor.px == before.px and actor.py == before.py,
       "renderer mutated gameplay identity or actor coordinates")
assert(map:warpAtCell(5, 5).def.destMap == before.redWarp, "renderer mutated Red house warp")
assert(map:warpAtCell(13, 5).def.destMap == before.rivalWarp, "renderer mutated rival house warp")
assert(map:warpAtCell(12, 11).def.destMap == before.oakWarp, "renderer mutated Oak lab warp")

print(("PASS building_first_loader_v0232 buildings=%d ground=%d materials=%d")
  :format(m2.buildings, m2.groundCells, m2.materialBuilds))
