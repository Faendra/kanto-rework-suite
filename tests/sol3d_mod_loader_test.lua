-- Headless compatibility gate for the Sol 3DWorld package against the
-- official Gen1Recomp mod loader. Run from a Gen1Recomp v0.2.32 checkout:
--
--   KRS_PACKAGE_DIR=/path/to/packages/kanto_rework_3dworld_hd2d \
--     luajit /path/to/this/test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

-- The upstream headless stub intentionally omits GPU primitives that no
-- engine-logic test needs. Renderer:available() correctly requires polygon
-- support on a real LOVE runtime, so provide only no-op primitives needed to
-- exercise KRS geometry paths without pretending to rasterize pixels.
love.graphics.polygon = love.graphics.polygon or function() end
love.graphics.ellipse = love.graphics.ellipse or function() end

local Loader = require("src.mods.Loader")
local Pipelines = require("src.render.Pipelines")

local packageDir = assert(os.getenv("KRS_PACKAGE_DIR"), "KRS_PACKAGE_DIR is required")

local RELATIVE_FILES = {
  "manifest.json",
  "main.lua",
  "sol3d/CameraContinuity.lua",
  "sol3d/NeighborScenes.lua",
  "sol3d/Presentation.lua",
  "sol3d/Projection.lua",
  "sol3d/Renderer.lua",
  "sol3d/SceneProfiles.lua",
  "sol3d/WorldAdapter.lua",
}

local function readAll(path)
  local f, err = io.open(path, "rb")
  assert(f, err)
  local value = f:read("*a")
  f:close()
  return value
end

local files = {}
local root = "mods/kanto_rework_3dworld_hd2d"
for _, rel in ipairs(RELATIVE_FILES) do
  files[root .. "/" .. rel] = readAll(packageDir .. "/" .. rel)
end

local function memfs(values)
  return {
    read = function(path)
      return values[path]
    end,
    getInfo = function(path)
      if values[path] then return { type = "file" } end
      local prefix = path .. "/"
      for key in pairs(values) do
        if key:sub(1, #prefix) == prefix then
          return { type = "directory" }
        end
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
assert(ok, "KRS mod loader rejected package: " .. table.concat(loader.errors, "; "))
assert(#loader.errors == 0,
  "KRS mod produced loader errors: " .. table.concat(loader.errors, "; "))

local exports = assert(loader.exports.kanto_rework_3dworld_hd2d,
  "KRS exports missing after load")
assert(type(exports.renderer) == "table", "renderer export missing")
assert(type(exports.adapter) == "table", "adapter export missing")
assert(type(exports.presentation) == "table", "presentation export missing")

Pipelines.install(data)
local found
for _, row in ipairs(Pipelines.list()) do
  if row.id == "krs_3dworld" then
    found = row
    break
  end
end
assert(found, "krs_3dworld render pipeline was not registered")
assert(found.def and found.def.label == "KRS 3DWORLD",
  "unexpected pipeline label")

-- Enabling the pipeline without an overworld must remain a clean vanilla
-- fallback. There is intentionally no game/ROM fixture in this compatibility
-- gate; a presentation mod must not require one merely to load.
Pipelines.setLevel("krs_3dworld", 1)
local selected = Pipelines.worldPipeline()
assert(selected == "krs_3dworld",
  "enabled KRS pipeline was not eligible under the augmented LOVE stub")
local out = Pipelines.drawWorld("krs_3dworld", {
  width = 320,
  height = 180,
  state = {},
})
assert(out == nil, "no-overworld draw should fall back by returning nil")
assert(Pipelines.worldPipeline() == "krs_3dworld",
  "clean nil fallback must not retire the pipeline")

-- Exercise the actual renderer path with a synthetic read-only scene. This is
-- not a pixel-quality test: LOVE drawing functions remain no-ops. It exists to
-- catch runtime errors in surface reconstruction, connected-water material,
-- authored structures/vegetation and contact-shadow code after the package has
-- passed through Gen1Recomp's official loader.
local function palletBlocks()
  local blocks = {}
  for i = 1, 90 do blocks[i] = 0x01 end
  local function put(bx, by, value)
    blocks[by * 10 + bx + 1] = value
  end
  put(2, 2, 0x38)
  put(3, 2, 0x39)
  put(2, 3, 0x3c)
  put(3, 3, 0x3d)
  return blocks
end

local function activeRows()
  local rows = {}
  for y = 0, 17 do
    local row = {}
    for x = 0, 19 do
      local ch = "."
      if x <= 1 or y <= 1 or x >= 18 or y >= 16 then ch = " " end
      if y >= 8 and y <= 11 and x >= 16 then ch = "~" end
      row[#row + 1] = ch
    end
    rows[#rows + 1] = table.concat(row)
  end
  return rows
end

local function tileDetailRows(width, height)
  local rows = {}
  for y = 1, height * 4 do
    local digit = tostring((y - 1) % 4)
    rows[y] = string.rep(digit, width * 4)
  end
  return rows
end

local function neighborRows()
  local rows = {}
  for y = 0, 17 do
    local row = {}
    for x = 0, 5 do
      local ch = "."
      if y >= 8 and y <= 11 and x <= 2 then ch = "~" end
      row[#row + 1] = ch
    end
    rows[#rows + 1] = table.concat(row)
  end
  return rows
end

local fixture = {
  mapId = "PALLET_TOWN",
  player = { x = 12, y = 9 },
  mapDef = {
    tileset = "OVERWORLD",
    width = 10,
    height = 9,
    blocks = palletBlocks(),
    warps = { { x = 5, y = 7 } },
  },
  tilesetDef = {},
  overview = {
    width = 20,
    height = 18,
    rows = activeRows(),
    tileDetailRows = tileDetailRows(20, 18),
  },
  neighbors = {
    {
      mapId = "ROUTE_21",
      offsetX = 20,
      offsetY = 0,
      mapDef = { tileset = "OVERWORLD", width = 3, height = 9, blocks = {} },
      tilesetDef = {},
      overview = {
        width = 6,
        height = 18,
        rows = neighborRows(),
        -- Intentionally absent: CP3D02C previews do not own the active map's
        -- fine material raster. CP3D02B must still render connected water.
        tileDetailRows = nil,
      },
    },
  },
}

local renderer = exports.renderer
local originalAdapter = renderer.adapter
renderer.adapter = { snapshot = function() return fixture end }
renderer:update(1 / 60, 1)
local rendered = renderer:drawWorld({
  width = 640,
  height = 360,
  state = { npcs = {} },
})
renderer.adapter = originalAdapter

assert(rendered ~= nil, "synthetic overworld did not produce a canvas")
assert((renderer.lastStats.cells or 0) > 0, "synthetic scene drew no cells")
assert((renderer.lastStats.waterCells or 0) > 0, "water material path was not exercised")
assert((renderer.lastStats.neighborCells or 0) > 0, "connected neighbor path was not exercised")
assert((renderer.lastStats.structures or 0) > 0, "authored structure path was not exercised")
assert((renderer.lastStats.vegetation or 0) > 0, "vegetation path was not exercised")
assert((renderer.lastStats.shadowCasters or 0)
       >= (renderer.lastStats.structures or 0) + (renderer.lastStats.vegetation or 0),
  "contact-shadow caster accounting is incomplete")
assert((renderer.materialTime or 0) > 0, "water material clock did not advance")

Pipelines.reset()
Pipelines.install(nil)
Loader.endSession()

print("PASS sol3d_mod_loader_test")
