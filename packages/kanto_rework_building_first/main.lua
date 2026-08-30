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
local PalletRivalHouse = loadLocal("building.PalletRivalHouse", "building/PalletRivalHouse.lua")
local PalletOakLab = loadLocal("building.PalletOakLab", "building/PalletOakLab.lua")
local SemanticSceneBuilder = loadLocal("building.SemanticSceneBuilder", "building/SemanticSceneBuilder.lua")
local WorldScene = loadLocal("building.WorldScene", "building/WorldScene.lua")
local WorldEnvelope = loadLocal("building.WorldEnvelope", "building/WorldEnvelope.lua")
local SceneProjection = loadLocal("building.SceneProjection", "building/SceneProjection.lua")
local AtlasSource = loadLocal("building.AtlasSource", "building/AtlasSource.lua")
local BuildingRenderer = loadLocal("building.BuildingRenderer", "building/BuildingRenderer.lua")

local buildingProfiles = { PalletRedHouse, PalletRivalHouse, PalletOakLab }
local sceneBuilder = SemanticSceneBuilder.new(buildingProfiles)
local renderer = BuildingRenderer.new(
  SceneProjection, AtlasSource, sceneBuilder, WorldScene, WorldEnvelope)

mod.exports.renderer = renderer
mod.exports.sceneBuilder = sceneBuilder
mod.exports.worldScene = WorldScene
mod.exports.worldEnvelope = WorldEnvelope
mod.exports.buildingProfiles = buildingProfiles
mod.exports.redHouseProfile = PalletRedHouse
mod.exports.rivalHouseProfile = PalletRivalHouse
mod.exports.oakLabProfile = PalletOakLab
mod.exports.projection = SceneProjection
mod.exports.atlasSource = AtlasSource
mod.exports.metrics = function() return renderer:metrics() end

mod.content.render_pipelines:register("krs_building_first", {
  label = "KRS FIRERED SKIN",
  levels = { "OFF", "FIRERED-SKIN-01", "FIRERED-SKIN-01", "FIRERED-SKIN-01" },
  hotkey = "8",
  priority = 70,
  available = function() return renderer:available() end,
  update = function(dt, level) renderer:update(dt, level) end,
  drawWorld = function(ctx) return renderer:drawWorld(ctx) end,
  invalidate = function() renderer:invalidate() end,
})
