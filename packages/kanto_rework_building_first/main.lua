local mod = ...

local engineRequire = require
local localModules = {}

local function localRequire(name, ...)
  local cached = localModules[name]
  if cached ~= nil then return cached end
  return engineRequire(name, ...)
end

local function loadLocal(name, path)
  local source, readErr = mod:read(path)
  if not source then
    error(("kanto_rework_building_first: cannot read %s: %s"):format(path, tostring(readErr)), 0)
  end
  local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. path)
  if not chunk then
    error(("kanto_rework_building_first: cannot compile %s: %s"):format(path, tostring(compileErr)), 0)
  end
  local previousRequire = require
  require = localRequire
  local ok, result = pcall(chunk)
  require = previousRequire
  if not ok then error(("kanto_rework_building_first: %s failed: %s"):format(path, tostring(result)), 0) end
  if result == nil then error(("kanto_rework_building_first: %s returned nil"):format(path), 0) end
  localModules[name] = result
  return result
end

local PalletRedHouse = loadLocal("building.PalletRedHouse", "building/PalletRedHouse.lua")
local SemanticSceneBuilder = loadLocal("building.SemanticSceneBuilder", "building/SemanticSceneBuilder.lua")
local SceneProjection = loadLocal("building.SceneProjection", "building/SceneProjection.lua")
local AtlasSource = loadLocal("building.AtlasSource", "building/AtlasSource.lua")
local BuildingRenderer = loadLocal("building.BuildingRenderer", "building/BuildingRenderer.lua")

local sceneBuilder = SemanticSceneBuilder.new(PalletRedHouse)
local renderer = BuildingRenderer.new(SceneProjection, AtlasSource, sceneBuilder)

mod.exports.renderer = renderer
mod.exports.sceneBuilder = sceneBuilder
mod.exports.redHouseProfile = PalletRedHouse
mod.exports.projection = SceneProjection
mod.exports.atlasSource = AtlasSource
mod.exports.metrics = function() return renderer:metrics() end

mod.content.render_pipelines:register("krs_building_first", {
  label = "KRS BUILDING FIRST",
  levels = { "OFF", "BUILDING-01 RAW", "BUILDING-01 RAW", "BUILDING-01 RAW" },
  hotkey = "8",
  priority = 70,
  available = function() return renderer:available() end,
  update = function(dt, level) renderer:update(dt, level) end,
  drawWorld = function(ctx) return renderer:drawWorld(ctx) end,
  invalidate = function() renderer:invalidate() end,
})
