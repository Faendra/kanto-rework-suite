-- Official Gen1Recomp v0.2.32 loader gate for TEST11 terrain topology.
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
  "manifest.json", "main.lua",
  "hd2d/SceneProjection.lua", "hd2d/SceneRenderer.lua",
  "hd2d/SceneStyle.lua", "hd2d/LivePolish.lua",
  "hd2d/VanillaMotifs.lua", "hd2d/LedgeTopology.lua", "hd2d/LedgeHopSmoothing.lua",
  "hd2d/DioramaPolish.lua", "hd2d/NaturalForms.lua", "hd2d/NaturalScale.lua",
  "hd2d/AtlasSource.lua", "hd2d/AtlasWorld.lua",
  "hd2d/SceneContinuity.lua", "hd2d/TerrainRemaster.lua",
  "hd2d/MaterialClassifier.lua", "hd2d/WorldAtmosphere.lua",
  "hd2d/Projection.lua", "hd2d/Relief.lua",
  "hd2d/WaterSurface.lua", "hd2d/Occlusion.lua",
  "hd2d/DepthComposer.lua", "hd2d/Renderer.lua",
}

local function readAll(path)
  local f, err = io.open(path, "rb")
  assert(f, err)
  local value = f:read("*a")
  f:close()
  return value
end

local files, root = {}, "mods/kanto_rework_hd2d_world"
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
    write = function(path, data) values[path] = data return true end,
  }
end

local data = {}
local loader = Loader.new({ fs = memfs(files), generation = 1, dev = true })
assert(loader:load(data),
  "TEST11 loader rejected package: " .. table.concat(loader.errors, "; "))
assert(#loader.errors == 0,
  "TEST11 loader errors: " .. table.concat(loader.errors, "; "))

local exports = assert(loader.exports.kanto_rework_hd2d_world, "TEST11 exports missing")
for _, name in ipairs({ "renderer", "projection", "materialClassifier",
  "vanillaMotifs", "ledgeTopology", "ledgeHopSmoothing",
  "naturalForms", "naturalScale", "atlasSource",
  "atlasWorld", "terrainRemaster", "atmosphere" }) do
  assert(type(exports[name]) == "table", name .. " export missing")
end

Pipelines.install(data)
Pipelines.setLevel("krs_hd2d_world", 2)
Pipelines.update(0)
assert(Pipelines.worldPipeline() == "krs_hd2d_world", "TEST11 pipeline unavailable")

local flatCalls = 0
local rendererStub = {
  drawBorderFill = function() flatCalls = flatCalls + 1 end,
  draw = function() flatCalls = flatCalls + 1 end,
  drawMapOnly = function() flatCalls = flatCalls + 1 end,
  drawCellBottom = function() flatCalls = flatCalls + 1 end,
}
rendererStub.image = love.graphics.newCanvas(128, 48)
rendererStub.quads = {}
for t = 0, 95 do
  rendererStub.quads[t] = love.graphics.newQuad((t % 16) * 8,
                                                math.floor(t / 16) * 8,
                                                8, 8, 128, 48)
end

local TREE = { 0x40, 0x41, 0x50, 0x51 }
local BOULDER = { 0x2A, 0x2B, 0x3A, 0x3B }
local LAWN, PATH, HOUSE = 0x2C, 0x39, 0x30
local W, H = 10, 9
local blocked = {}
local function put(x, y, kind) blocked[y * 32 + x] = kind end
for y = 1, 3 do put(7, y, "tree") end
put(1, 5, "boulder")
for y = 2, 3 do for x = 2, 4 do put(x, y, "house") end end

local map = { id = "SYNTHETIC_TEST11_PALLET", def = { tileset = "OVERWORLD" },
              widthCells = W, heightCells = H, renderer = rendererStub }
function map:inBounds(x, y) return x >= 0 and y >= 0 and x < W and y < H end
function map:isWaterCell(x, y) return y == H - 1 end
function map:isGrassCell() return false end
function map:isWarpTileCell(x, y) return x == 3 and y == 4 end
function map:warpAtCell(x, y) if self:isWarpTileCell(x, y) then return { index = 1 } end end
function map:isWalkableCell(x, y)
  return not self:isWaterCell(x, y) and blocked[y * 32 + x] == nil
end
function map:cellTile(x, y)
  local kind = blocked[y * 32 + x]
  if kind == "tree" then return TREE[3] end
  if kind == "boulder" then return BOULDER[3] end
  if kind == "house" then return HOUSE end
  if self:isWaterCell(x, y) then return 0x14 end
  return (x == 5 or x == 6) and PATH or LAWN
end
function map:tileAt(tx, ty)
  local cx, cy = math.floor(tx / 2), math.floor(ty / 2)
  local kind = blocked[cy * 32 + cx]
  local qi = (ty % 2) * 2 + (tx % 2) + 1
  if kind == "tree" then return TREE[qi] end
  if kind == "boulder" then return BOULDER[qi] end
  if kind == "house" then return HOUSE end
  if self:isWaterCell(cx, cy) then return 0x14 end
  return (cx == 5 or cx == 6) and PATH or LAWN
end
function map:blockAt() return 0x01 end

local actorQuad = love.graphics.newQuad(0, 0, 16, 16, 16, 16)
local actorImage = love.graphics.newCanvas(16, 16)
local sprite = {
  getPoseGeometry = function()
    return { quad = actorQuad, width = 16, height = 16, anchorX = 8, anchorY = 16 }
  end,
  resolveImage = function() return actorImage end,
}
local actor = { id = "RED", px = 5 * 16, py = 5 * 16 }
function actor:pose() return sprite, self.px, self.py, "down", 0, false, false end

local state = { map = map, neighbors = {}, entities = { actor }, ghosts = {}, player = actor }
local ctx = {
  width = 640, height = 576, vw = 160, vh = 144, scale = 4, level = 2,
  state = state, cam = { x = 0, y = 0 }, bgY = 0,
  paletteFor = function()
    return { {255,255,255}, {170,190,160}, {90,110,90}, {30,35,32} }
  end,
  drawFx = function() end,
}

local rendered = Pipelines.drawWorld("krs_hd2d_world", ctx)
assert(rendered ~= nil, "TEST11 renderer produced no canvas")
local r = exports.renderer
assert((r.lastAtlasDirectFrames or 0) == 1, "TEST11 direct-atlas path inactive")
assert((r.lastCompatibilityCaptureFrames or 0) == 0, "TEST11 used compatibility capture")
assert(flatCalls == 0, "TEST11 invoked flattened map drawing")
assert((r.lastFlatSourceFallbacks or 0) == 0, "TEST11 leaked flat-source textures")
assert((r.lastAtlasGroundCells or 0) > 0, "TEST11 atlas ground missing")
assert((r.lastAtlasNaturalObjects or 0) > 0, "TEST11 atlas natural objects missing")
assert((r.lastAtlasStructures or 0) > 0, "TEST11 atlas structure missing")
assert((r.lastRaisedLawnCells or 0) == 0, "TEST11 still raises lawn semantically")
assert((r.lastTerrainSkirts or 0) == 0, "TEST11 still emits semantic terrain skirts")
assert((r.lastFlatOutdoorCells or 0) > 20, "TEST11 ordinary outdoor terrain not coplanar")
assert((r.lastLedgeFaces or 0) == 0, "TEST11 no-ledge loader scene fabricated ledge faces")
assert((r.lastSmoothedLedgeActors or 0) == 0,
       "TEST11 no-ledge loader scene unexpectedly smoothed an actor")
assert((r.lastPathCells or 0) > 0, "TEST11 path surface classification missing")
assert((r.lastScaledTrees or 0) > 0, "TEST11 tree scale tuning inactive")
assert((r.lastFlattenedBoulders or 0) > 0, "TEST11 boulder flattening inactive")
assert(r.lastActors == 1, "TEST11 actor billboard missing")

print("PASS hd2d_scene_loader_test11")