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

local Projection = loadLocal("hd2d.Projection", "hd2d/Projection.lua")
local MaterialClassifier = loadLocal("hd2d.MaterialClassifier", "hd2d/MaterialClassifier.lua")
local Relief = loadLocal("hd2d.Relief", "hd2d/Relief.lua")
local WaterSurface = loadLocal("hd2d.WaterSurface", "hd2d/WaterSurface.lua")
local Occlusion = loadLocal("hd2d.Occlusion", "hd2d/Occlusion.lua")
local DepthComposer = loadLocal("hd2d.DepthComposer", "hd2d/DepthComposer.lua")
local WorldAtmosphere = loadLocal("hd2d.WorldAtmosphere", "hd2d/WorldAtmosphere.lua")
local Renderer = loadLocal("hd2d.Renderer", "hd2d/Renderer.lua")

local renderer = Renderer.new(Projection, MaterialClassifier)
local relief = Relief.new(MaterialClassifier)
local water = WaterSurface.new(MaterialClassifier)
local occlusion = Occlusion.new()
local depthComposer = DepthComposer.new(relief, occlusion, WaterSurface)
local atmosphere = WorldAtmosphere.new()

renderer.drawSolidRelief = function()
  return 0
end

renderer.waterSurfaceZ = function(self)
  return WaterSurface.surfaceZ(self.level)
end

local drawWaterLight = renderer.drawWaterLight
renderer.drawWaterLight = function(self, ctx, proj)
  water:draw(self, ctx, proj, self.level)
  drawWaterLight(self, ctx, proj)
end

renderer.drawActors = function(self, ctx, proj)
  return depthComposer:draw(self, ctx, proj)
end

local function playerFocusY(canvas, ctx)
  if type(ctx) ~= "table" or not ctx.state or not ctx.state.player
     or not ctx.state.map or not canvas then return nil end
  local player = ctx.state.player
  if type(player.px) ~= "number" or type(player.py) ~= "number" then return nil end
  if not (ctx.vw and ctx.vh and ctx.width and ctx.height and ctx.cam) then return nil end

  local ok, proj = pcall(Projection.new, ctx, math.max(1, renderer.level))
  if not ok or not proj then return nil end
  local wx, wy = player.px + 8, player.py + 16
  local surfaceZ = renderer:surfaceZForWorld(ctx.state.map, wx, wy)
  local _, sy = proj:projectWorld(wx, wy, surfaceZ)
  local h = canvas.getHeight and canvas:getHeight() or 0
  if type(sy) ~= "number" or h <= 0 then return nil end
  return sy / h
end

mod.exports.renderer = renderer
mod.exports.projection = Projection
mod.exports.materialClassifier = MaterialClassifier
mod.exports.relief = relief
mod.exports.water = water
mod.exports.occlusion = occlusion
mod.exports.depthComposer = depthComposer
mod.exports.atmosphere = atmosphere

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
