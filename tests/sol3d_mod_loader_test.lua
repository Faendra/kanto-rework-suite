-- Headless compatibility gate for the Sol 3DWorld package against the
-- official Gen1Recomp mod loader. Run from a Gen1Recomp v0.2.32 checkout:
--
--   KRS_PACKAGE_DIR=/path/to/packages/kanto_rework_3dworld_hd2d \
--     luajit /path/to/this/test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

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
    write = function()
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
  "enabled KRS pipeline was not eligible under the LOVE stub")
local out = Pipelines.drawWorld("krs_3dworld", {
  width = 320,
  height = 180,
  state = {},
})
assert(out == nil, "no-overworld draw should fall back by returning nil")
assert(Pipelines.worldPipeline() == "krs_3dworld",
  "clean nil fallback must not retire the pipeline")

Pipelines.reset()
Pipelines.install(nil)
Loader.endSession()

print("PASS sol3d_mod_loader_test")
