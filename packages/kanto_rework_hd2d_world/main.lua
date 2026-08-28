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

-- TEST1 showed that a warp adjacent to one very large connected blocked mass
-- could promote the whole mass to a building. Keep the classifier data-driven,
-- but require architectural masses to be compact, dense and away from map
-- boundaries. Oversized natural masses fall back to vegetation/boundary/mass.
local NATURAL_TILESETS = { OVERWORLD = true, FOREST = true }
local baseClassify = MaterialClassifier.classify
MaterialClassifier.classify = function(map, cx, cy)
  local material = baseClassify(map, cx, cy)
  if material.kind == "solid" and material.family == "structure" then
    local mass = MaterialClassifier.massInfo(map, cx, cy)
    local compact = mass
      and not mass.touchesEdge
      and (mass.spanX or 0) <= 10
      and (mass.spanY or 0) <= 7
      and (mass.size or 0) <= 64
      and (mass.density or 0) >= 0.35

    if not compact then
      local tileset = map and map.def and map.def.tileset
      if mass and NATURAL_TILESETS[tileset]
         and (mass.repeatRatio or 0) >= 0.45 then
        material.family, material.heightScale = "vegetation", 1.42
      elseif mass and mass.touchesEdge then
        material.family, material.heightScale = "boundary", 1.28
      else
        material.family, material.heightScale = "mass", 1.0
      end
    end
  end
  return material
end

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

-- Gen1Recomp's flat path fills areas beyond an outdoor map with a border tile.
-- Once perspective is applied that fill becomes the giant grey slabs visible in
-- TEST1. Preserve the engine call for compatibility, then clear it before the
-- projected source is captured and replace it with a palette-derived ground
-- neutral. Interiors/caves retain the original Renderer path unchanged.
local OUTDOOR_TILESETS = {
  OVERWORLD = true,
  FOREST = true,
  SHIP_PORT = true,
  PLATEAU = true,
}

local function normalizedColor(color, fallback)
  if type(color) ~= "table" then
    return fallback[1], fallback[2], fallback[3]
  end
  local r, g, b = tonumber(color[1]), tonumber(color[2]), tonumber(color[3])
  if not r or not g or not b then
    return fallback[1], fallback[2], fallback[3]
  end
  if r > 1 or g > 1 or b > 1 then
    r, g, b = r / 255, g / 255, b / 255
  end
  return r, g, b
end

local function outdoorSourceColor(ctx, map)
  local fallback = { 0.44, 0.54, 0.40 }
  local palette = ctx.paletteFor and ctx.paletteFor(map) or nil
  local c2 = type(palette) == "table" and (palette[2] or palette[1]) or nil
  local c3 = type(palette) == "table" and (palette[3] or palette[2]) or nil
  local r2, g2, b2 = normalizedColor(c2, fallback)
  local r3, g3, b3 = normalizedColor(c3, fallback)
  return r2 * 0.45 + r3 * 0.55,
         g2 * 0.45 + g3 * 0.55,
         b2 * 0.45 + b3 * 0.55
end

local baseDrawTerrainSource = renderer.drawTerrainSource
renderer.lastOutdoorBorderSuppressed = false
renderer.drawTerrainSource = function(self, ctx)
  local state = ctx and ctx.state
  local map = state and state.map
  local tileset = map and map.def and map.def.tileset
  if not OUTDOOR_TILESETS[tileset] then
    self.lastOutdoorBorderSuppressed = false
    return baseDrawTerrainSource(self, ctx)
  end
  if not (map and map.renderer and ctx.cam) then return false end

  self.lastOutdoorBorderSuppressed = true
  local cam = ctx.cam
  local bgY = ctx.bgY or cam.y

  -- Execute the normal border call inside the source canvas, then reset all
  -- graphics state and erase its pixels before drawing the actual maps.
  love.graphics.push("all")
  love.graphics.setCanvas(self.source)
  map.renderer:drawBorderFill(cam.x, bgY, ctx.vw, ctx.vh)
  love.graphics.pop()

  love.graphics.push("all")
  love.graphics.setCanvas(self.source)
  local r, g, b = outdoorSourceColor(ctx, map)
  love.graphics.clear(r, g, b, 1)
  love.graphics.setColor(1, 1, 1, 1)
  map.renderer:draw(cam.x, bgY, ctx.vw, ctx.vh)
  for _, nb in ipairs(state.neighbors or {}) do
    if nb.map and nb.map.renderer then
      nb.map.renderer:drawMapOnly(cam.x - (nb.ox or 0),
                                  bgY - (nb.oy or 0), ctx.vw, ctx.vh)
    end
  end
  love.graphics.setCanvas()
  love.graphics.pop()
  return true
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
