-- Official Gen1Recomp v0.2.32 loader gate for the HD2D scene renderer.
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
  "hd2d/SceneStyle.lua",
  "hd2d/LivePolish.lua",
  "hd2d/VanillaMotifs.lua",
  "hd2d/DioramaPolish.lua",
  "hd2d/NaturalForms.lua",
  "hd2d/AtlasSource.lua",
  "hd2d/AtlasWorld.lua",
  "hd2d/SceneContinuity.lua",
  "hd2d/TerrainRemaster.lua",
  "hd2d/MaterialClassifier.lua",
  "hd2d/WorldAtmosphere.lua",
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
for _, name in ipairs({
  "renderer", "projection", "materialClassifier", "sceneStyle", "livePolish",
  "vanillaMotifs", "dioramaPolish", "naturalForms", "atlasSource", "atlasWorld",
  "sceneContinuity", "terrainRemaster", "atmosphere",
}) do
  assert(type(exports[name]) == "table", name .. " export missing")
end

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
-- Mirror the public runtime fields exposed by Gen1Recomp TileRenderer.new:
-- `image` is the exact generated tileset atlas and `quads[tileId]` addresses
-- its 8x8 cells. TEST8 must use these rather than needing a flat-map capture.
rendererStub.image = love.graphics.newCanvas(128, 48)
rendererStub.quads = {}
for t = 0, 95 do
  rendererStub.quads[t] = love.graphics.newQuad((t % 16) * 8,
                                                math.floor(t / 16) * 8,
                                                8, 8, 128, 48)
end

local TREE = { 0x2A, 0x2B, 0x3A, 0x3B }
local BOULDER = { 0x40, 0x41, 0x50, 0x51 }
local blocked = {}
for y = 2, 3 do for x = 2, 4 do blocked[y * 32 + x] = "structure" end end
for y = 1, 3 do blocked[y * 32 + 7] = "tree" end
blocked[5 * 32 + 1] = "boulder"

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
function map:isGrassCell() return false end
function map:isWarpTileCell(x, y) return x == 3 and y == 4 end
function map:warpAtCell(x, y)
  if self:isWarpTileCell(x, y) then return { index = 1 } end
  return nil
end
function map:isWalkableCell(x, y)
  return not self:isWaterCell(x, y) and blocked[y * 32 + x] == nil
end
function map:cellTile(x, y)
  local kind = blocked[y * 32 + x]
  if kind == "tree" then return 0x3A end
  if kind == "boulder" then return 0x50 end
  if kind == "structure" then return 0x30 end
  if self:isWaterCell(x, y) then return 0x14 end
  return (x == 5 or x == 6) and 0x39 or 0x2C
end
function map:tileAt(tx, ty)
  local cx, cy = math.floor(tx / 2), math.floor(ty / 2)
  local kind = blocked[cy * 32 + cx]
  local qx, qy = tx % 2, ty % 2
  local qi = qy * 2 + qx + 1
  if kind == "tree" then return TREE[qi] end
  if kind == "boulder" then return BOULDER[qi] end
  if kind == "structure" then return 0x30 end
  if self:isWaterCell(cx, cy) then return 0x14 end
  return (cx == 5 or cx == 6) and 0x39 or 0x2C
end
function map:blockAt() return 0x01 end

local treeMaterial = exports.materialClassifier.classify(map, 7, 2)
assert(treeMaterial.family == "vegetation" and treeMaterial.motif == "tree",
  "canonical vanilla tree quartet was not promoted to vegetation")
local boulderMaterial = exports.materialClassifier.classify(map, 1, 5)
assert(boulderMaterial.family == "boundary" and boulderMaterial.motif == "boulder",
  "canonical vanilla boulder quartet was not kept distinct from trees")

local neighborMap = {
  id = "SYNTHETIC_ROUTE",
  def = { tileset = "OVERWORLD" },
  widthCells = 8, heightCells = 8, renderer = rendererStub,
}
function neighborMap:inBounds(x, y)
  return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
end
function neighborMap:isWaterCell() return false end
function neighborMap:isGrassCell() return false end
function neighborMap:isWarpTileCell() return false end
function neighborMap:warpAtCell() return nil end
function neighborMap:isWalkableCell() return true end
function neighborMap:cellTile() return 0x2C end
function neighborMap:tileAt() return 0x2C end
function neighborMap:blockAt() return 0x01 end

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
  entities = { actor }, ghosts = {}, player = actor,
}
local worldCtx = {
  width = 640, height = 576, vw = 160, vh = 144, scale = 4, level = 2,
  state = state, cam = { x = 0, y = 0 }, bgY = 0,
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
  "world axes do not rotate in opposite X directions")
assert(by > ay and cy > ay,
  "world axes do not recede through perspective")
assert((proj.elevation / math.max(0.001, proj.tileH)) >= 2.0,
  "DEPTH camera regressed too far toward top-down")

local rendered = Pipelines.drawWorld("krs_hd2d_world", worldCtx)
assert(rendered ~= nil, "scene renderer produced no canvas")
assert(exports.renderer.lastGroundCells >= 40, "shared ground plane missing")
assert(exports.renderer.lastStructures >= 1, "structure volume missing")
assert(exports.renderer.lastVegetation >= 1, "tree motif did not emit vegetation")
assert(exports.renderer.lastBoundaries >= 1, "boulder motif did not emit a boundary")
assert(exports.renderer.lastActors == 1, "actor billboard missing")
assert((exports.renderer.lastAtlasGroundCells or 0) > 0,
  "TEST8 did not source walkable terrain directly from runtime tileset atlas")
assert((exports.renderer.lastAtlasNaturalObjects or 0) > 0,
  "TEST8 did not source natural object pixels directly from runtime tileset atlas")
assert((exports.renderer.lastAtlasCellTextures or 0) > 0,
  "TEST8 created no cached 16x16 cells from runtime 8x8 atlas tiles")
assert((exports.renderer.lastRaisedLawnCells or 0) > 0,
  "terrain remaster did not raise lawn cells")
assert((exports.renderer.lastPathCells or 0) > 0,
  "terrain remaster did not preserve path cells")
assert((exports.renderer.lastTerrainSkirts or 0) > 0,
  "lawn/path elevation transition emitted no terrain skirts")
assert((exports.renderer.lastApronCells or 0) > 0,
  "outdoor world apron missing")
assert((exports.renderer.lastInteriorShellPanels or 0) == 0,
  "outdoor map incorrectly received an interior shell")
assert(drawCounts.current >= 2 and drawCounts.neighbor >= 1,
  "compatibility capture did not include current and connected maps")
assert(drawCounts.fx == 1 and exports.renderer.lastFx == 1,
  "field FX bridge did not run through remastered surface projection")

local presented = Pipelines.worldPresent(rendered, worldCtx)
assert(presented == rendered and exports.atmosphere.lastBypassed == true,
  "headless atmosphere fallback did not preserve scene canvas")

local interiorMap = {
  id = "SYNTHETIC_REDS_HOUSE",
  def = { tileset = "REDSHOUSE1" },
  widthCells = 6, heightCells = 6, renderer = rendererStub,
}
function interiorMap:inBounds(x, y)
  return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
end
function interiorMap:isWaterCell() return false end
function interiorMap:isGrassCell() return false end
function interiorMap:isWarpTileCell() return false end
function interiorMap:warpAtCell() return nil end
function interiorMap:isWalkableCell() return true end
function interiorMap:cellTile() return 0x01 end
function interiorMap:tileAt() return 0x01 end
function interiorMap:blockAt() return 0x01 end

local interiorState = {
  map = interiorMap, neighbors = {}, entities = { actor }, ghosts = {}, player = actor,
}
local interiorCtx = {
  width = 640, height = 576, vw = 160, vh = 144, scale = 4, level = 2,
  state = interiorState, cam = { x = 0, y = 0 }, bgY = 0,
  paletteFor = worldCtx.paletteFor, drawFx = function() end,
}
local interiorRendered = Pipelines.drawWorld("krs_hd2d_world", interiorCtx)
assert(interiorRendered ~= nil, "interior scene renderer produced no canvas")
assert((exports.renderer.lastInteriorShellPanels or 0) == 4,
  "room-like interior did not receive dollhouse shell")
assert((exports.renderer.lastApronCells or 0) == 0,
  "interior map incorrectly received outdoor apron")
assert((exports.renderer.lastRaisedLawnCells or 0) == 0,
  "interior floor was incorrectly terrain-remastered as outdoor lawn")

Pipelines.reset()
Pipelines.install(nil)
Loader.endSession()
print("PASS hd2d_scene_loader_test")
