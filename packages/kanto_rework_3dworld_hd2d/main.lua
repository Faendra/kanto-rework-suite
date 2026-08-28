local mod = ...

-- Mod-authored multi-file code must be loaded through the mod filesystem,
-- not the host package.path.  Gen1Recomp's sandbox intentionally exposes
-- mod:read + sandboxed load for this purpose.
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
    error(("kanto_rework_3dworld_hd2d: cannot read %s: %s")
      :format(path, tostring(readErr)), 0)
  end

  local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. path)
  if not chunk then
    error(("kanto_rework_3dworld_hd2d: cannot compile %s: %s")
      :format(path, tostring(compileErr)), 0)
  end

  -- Loaded chunks share this mod's sandbox environment.  Replace only this
  -- mod's `require` while the chunk executes so local module names resolve
  -- from our cache, then restore the engine-provided sandbox require.
  local previousRequire = require
  require = localRequire
  local ok, result = pcall(chunk)
  require = previousRequire
  if not ok then
    error(("kanto_rework_3dworld_hd2d: %s failed: %s")
      :format(path, tostring(result)), 0)
  end
  if result == nil then
    error(("kanto_rework_3dworld_hd2d: %s returned nil"):format(path), 0)
  end

  localModules[name] = result
  return result
end

local WorldAdapter = loadLocal("sol3d.WorldAdapter", "sol3d/WorldAdapter.lua")
loadLocal("sol3d.Projection", "sol3d/Projection.lua")
loadLocal("sol3d.SceneProfiles", "sol3d/SceneProfiles.lua")
local Renderer = loadLocal("sol3d.Renderer", "sol3d/Renderer.lua")
local Presentation = loadLocal("sol3d.Presentation", "sol3d/Presentation.lua")

local adapter = WorldAdapter.new(mod)
local renderer = Renderer.new(adapter)
local presentation = Presentation.new()

mod.exports.renderer = renderer
mod.exports.adapter = adapter
mod.exports.presentation = presentation

mod.content.render_pipelines:register("krs_3dworld", {
  label = "KRS 3DWORLD",
  levels = { "OFF", "HD2D", "DEPTH", "CINE" },
  hotkey = "6",
  priority = 60,
  available = function()
    return renderer:available()
  end,
  update = function(dt, level)
    renderer:update(dt, level)
    presentation:update(dt, level)
  end,
  drawWorld = function(ctx)
    return renderer:drawWorld(ctx)
  end,
  worldPresent = function(canvas, ctx)
    -- Presentation failures degrade locally to the unprocessed 3DWorld
    -- canvas.  The geometry renderer remains active instead of retiring the
    -- entire display pipeline because an optional shader is unavailable.
    return presentation:worldPresent(canvas, ctx, renderer.level)
  end,
  invalidate = function()
    presentation:invalidate()
  end,
})
