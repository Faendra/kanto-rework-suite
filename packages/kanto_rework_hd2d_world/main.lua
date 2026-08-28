local mod = ...

-- Keep the experiment inside the Gen1Recomp mod sandbox. Local files are
-- read through mod:read; engine modules still resolve through the sandboxed
-- require supplied by the loader.
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

local Projection = loadLocal("hd2d.Projection", "hd2d/Projection.lua")
local MaterialClassifier = loadLocal("hd2d.MaterialClassifier", "hd2d/MaterialClassifier.lua")
local Relief = loadLocal("hd2d.Relief", "hd2d/Relief.lua")
local WaterSurface = loadLocal("hd2d.WaterSurface", "hd2d/WaterSurface.lua")
local Occlusion = loadLocal("hd2d.Occlusion", "hd2d/Occlusion.lua")
local DepthComposer = loadLocal("hd2d.DepthComposer", "hd2d/DepthComposer.lua")
local Renderer = loadLocal("hd2d.Renderer", "hd2d/Renderer.lua")

local renderer = Renderer.new(Projection, MaterialClassifier)
local relief = Relief.new(MaterialClassifier)
local water = WaterSurface.new(MaterialClassifier)
local occlusion = Occlusion.new()
local depthComposer = DepthComposer.new(relief, occlusion, WaterSurface)

-- Raised terrain and upright actors must share one painter order. Suppress the
-- renderer's old terrain-first pass; DepthComposer emits both row geometry and
-- billboards by world baseline Y inside drawActors below.
renderer.drawSolidRelief = function()
  return 0
end

-- Preserve the renderer's restrained animated highlight, but make the actual
-- water geometry a lower continuous plane first. The original/current water
-- pixels remain the material source; only their presentation depth changes.
local drawWaterLight = renderer.drawWaterLight
renderer.drawWaterLight = function(self, ctx, proj)
  water:draw(self, ctx, proj, self.level)
  drawWaterLight(self, ctx, proj)
end

renderer.drawActors = function(self, ctx, proj)
  return depthComposer:draw(self, ctx, proj)
end

mod.exports.renderer = renderer
mod.exports.projection = Projection
mod.exports.materialClassifier = MaterialClassifier
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
  invalidate = function()
    renderer:invalidate()
    MaterialClassifier.invalidate()
    occlusion:invalidate()
  end,
})
