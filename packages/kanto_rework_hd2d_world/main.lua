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
    error(("kanto_rework_hd2d_world: cannot read %s: %s")
      :format(path, tostring(readErr)), 0)
  end

  local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. path)
  if not chunk then
    error(("kanto_rework_hd2d_world: cannot compile %s: %s")
      :format(path, tostring(compileErr)), 0)
  end

  local previousRequire = require
  require = localRequire
  local ok, result = pcall(chunk)
  require = previousRequire
  if not ok then
    error(("kanto_rework_hd2d_world: %s failed: %s")
      :format(path, tostring(result)), 0)
  end
  if result == nil then
    error(("kanto_rework_hd2d_world: %s returned nil"):format(path), 0)
  end

  localModules[name] = result
  return result
end

local SceneProjection = loadLocal("hd2d.SceneProjection", "hd2d/SceneProjection.lua")
local MaterialClassifier = loadLocal("hd2d.MaterialClassifier", "hd2d/MaterialClassifier.lua")
local SceneRenderer = loadLocal("hd2d.SceneRenderer", "hd2d/SceneRenderer.lua")
local SceneStyle = loadLocal("hd2d.SceneStyle", "hd2d/SceneStyle.lua")
local LivePolish = loadLocal("hd2d.LivePolish", "hd2d/LivePolish.lua")
local VanillaMotifs = loadLocal("hd2d.VanillaMotifs", "hd2d/VanillaMotifs.lua")
local DioramaPolish = loadLocal("hd2d.DioramaPolish", "hd2d/DioramaPolish.lua")
local NaturalForms = loadLocal("hd2d.NaturalForms", "hd2d/NaturalForms.lua")
local NaturalScale = loadLocal("hd2d.NaturalScale", "hd2d/NaturalScale.lua")
local AtlasSource = loadLocal("hd2d.AtlasSource", "hd2d/AtlasSource.lua")
local AtlasWorld = loadLocal("hd2d.AtlasWorld", "hd2d/AtlasWorld.lua")
local SceneContinuity = loadLocal("hd2d.SceneContinuity", "hd2d/SceneContinuity.lua")
local TerrainRemaster = loadLocal("hd2d.TerrainRemaster", "hd2d/TerrainRemaster.lua")
local WorldAtmosphere = loadLocal("hd2d.WorldAtmosphere", "hd2d/WorldAtmosphere.lua")

-- Keep the previous modules loadable/exported during the transition so saved
-- diagnostics and downstream KRS tooling do not break, but the live pipeline
-- below no longer draws the strip-projected renderer at all.
local LegacyProjection = loadLocal("hd2d.Projection", "hd2d/Projection.lua")
local Relief = loadLocal("hd2d.Relief", "hd2d/Relief.lua")
local WaterSurface = loadLocal("hd2d.WaterSurface", "hd2d/WaterSurface.lua")
local Occlusion = loadLocal("hd2d.Occlusion", "hd2d/Occlusion.lua")
local DepthComposer = loadLocal("hd2d.DepthComposer", "hd2d/DepthComposer.lua")
local LegacyRenderer = loadLocal("hd2d.Renderer", "hd2d/Renderer.lua")

local renderer = SceneStyle.apply(SceneRenderer.new(SceneProjection, MaterialClassifier))
renderer = LivePolish.apply(renderer)
-- LivePolish/SceneStyle install broad compatibility heuristics first. The
-- canonical vanilla 2x2 tile motifs are deliberately installed afterwards so
-- real OVERWORLD trees/boulders win over topology-only boundary guesses.
VanillaMotifs.install(MaterialClassifier)
renderer = DioramaPolish.apply(renderer)
renderer = NaturalForms.apply(renderer)
-- TEST8 live capture proved the canonical forms were correct but oversized:
-- preserve their vanilla pixels while reducing repeated tree-wall height and
-- flattening boulder relief before atlas textures are injected.
renderer = NaturalScale.apply(renderer)
-- Gen1Recomp already keeps the exact generated 8x8 tileset atlas on each map
-- renderer. Prefer that source over a captured flat-map framebuffer for all
-- walkable terrain and natural scene objects. Capture remains a compatibility
-- fallback for engines/tests that do not expose image/quads.
renderer = AtlasWorld.apply(renderer, AtlasSource)
renderer = SceneContinuity.apply(renderer)
renderer = TerrainRemaster.apply(renderer)

local atmosphere = WorldAtmosphere.new()

local legacyRenderer = LegacyRenderer.new(LegacyProjection, MaterialClassifier)
local relief = Relief.new(MaterialClassifier)
local water = WaterSurface.new(MaterialClassifier)
local occlusion = Occlusion.new()
local depthComposer = DepthComposer.new(relief, occlusion, WaterSurface)

local function playerFocusY(canvas, ctx)
  if type(ctx) ~= "table" or not ctx.state or not ctx.state.player
     or not ctx.state.map or not canvas then return nil end
  local player = ctx.state.player
  if type(player.px) ~= "number" or type(player.py) ~= "number" then return nil end
  if not (ctx.width and ctx.height and ctx.cam) then return nil end

  local ok, proj = pcall(SceneProjection.new, ctx, math.max(1, renderer.level))
  if not ok or not proj then return nil end
  local wx, wy = player.px + 8, player.py + 12
  local scenes = renderer:scenes(ctx.state)
  local surfaceZ = renderer:surfaceZForWorld(scenes, wx, wy)
  local _, sy = proj:worldPixel(wx, wy, surfaceZ)
  local h = canvas.getHeight and canvas:getHeight() or 0
  if type(sy) ~= "number" or h <= 0 then return nil end
  return sy / h
end

mod.exports.renderer = renderer
mod.exports.projection = SceneProjection
mod.exports.materialClassifier = MaterialClassifier
mod.exports.sceneStyle = SceneStyle
mod.exports.livePolish = LivePolish
mod.exports.vanillaMotifs = VanillaMotifs
mod.exports.dioramaPolish = DioramaPolish
mod.exports.naturalForms = NaturalForms
mod.exports.naturalScale = NaturalScale
mod.exports.atlasSource = AtlasSource
mod.exports.atlasWorld = AtlasWorld
mod.exports.sceneContinuity = SceneContinuity
mod.exports.terrainRemaster = TerrainRemaster
mod.exports.atmosphere = atmosphere
mod.exports.legacy = {
  renderer = legacyRenderer,
  projection = LegacyProjection,
  relief = relief,
  water = water,
  occlusion = occlusion,
  depthComposer = depthComposer,
}
-- Backward-compatible named exports for KRS diagnostics only.
mod.exports.relief = relief
mod.exports.water = water
mod.exports.occlusion = occlusion
mod.exports.depthComposer = depthComposer

mod.content.render_pipelines:register("krs_hd2d_world", {
  label = "KRS HD2D WORLD",
  levels = { "OFF", "HD2D", "DEPTH", "CINEMA" },
  hotkey = "7",
  priority = 65,
  available = function()
    return renderer:available()
  end,
  update = function(dt, level)
    renderer:update(dt, level)
  end,
  drawWorld = function(ctx)
    return renderer:drawWorld(ctx)
  end,
  worldPresent = function(canvas, ctx)
    return atmosphere:present(canvas, ctx, renderer.level,
                              playerFocusY(canvas, ctx))
  end,
  invalidate = function()
    renderer:invalidate()
    atmosphere:invalidate()
    MaterialClassifier.invalidate()
    occlusion:invalidate()
  end,
})
