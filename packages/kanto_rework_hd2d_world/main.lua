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
local WorldAtmosphere = loadLocal("hd2d.WorldAtmosphere", "hd2d/WorldAtmosphere.lua")
local Renderer = loadLocal("hd2d.Renderer", "hd2d/Renderer.lua")

local renderer = Renderer.new(Projection, MaterialClassifier)
local relief = Relief.new(MaterialClassifier)
local water = WaterSurface.new(MaterialClassifier)
local occlusion = Occlusion.new()
local depthComposer = DepthComposer.new(relief, occlusion, WaterSurface)
local atmosphere = WorldAtmosphere.new()

-- Raised terrain and upright actors must share one painter order. Suppress the
-- renderer's old terrain-first pass; DepthComposer emits both row geometry and
-- billboards by world baseline Y inside drawActors below.
renderer.drawSolidRelief = function()
  return 0
end

-- One contact-plane resolver is shared by water geometry, actors and the
-- optional local highlight so all three agree on the exact Z value.
renderer.waterSurfaceZ = function(self)
  return WaterSurface.surfaceZ(self.level)
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

-- Final semantic polish. Relief already replaces the flat blocked source tiles,
-- but strip projection shears neighbouring rows by sub-cell amounts. A small
-- terrain-texture overscan hides those seams underneath the volume. Vegetation
-- then receives one upright source-textured billboard at its exposed front row:
-- north/south collision depth no longer becomes a tower of tilted tile slabs,
-- while the original Pokémon pixel texture stays visible in the canopy.
local CELL = 16
local POLISH_DONORS = {
  { 0, 1 }, { -1, 0 }, { 1, 0 }, { 0, -1 },
  { -1, 1 }, { 1, 1 }, { -2, 0 }, { 2, 0 },
}

local function polishDonor(map, cx, cy)
  local grass
  for _, d in ipairs(POLISH_DONORS) do
    local nx, ny = cx + d[1], cy + d[2]
    local material = MaterialClassifier.classify(map, nx, ny)
    if material.kind == "ground" then return nx, ny end
    if not grass and material.kind == "grass" then grass = { nx, ny } end
  end
  if grass then return grass[1], grass[2] end
  return nil
end

local function drawPolishMask(host, ctx, proj, map, cx, cy, ox, oy)
  local donorX, donorY = polishDonor(map, cx, cy)
  if not donorX then return false end
  local sourceX = donorX * CELL + ox - proj.camX
  local sourceY = donorY * CELL + oy - proj.bgY
  if sourceX < 0 or sourceY < 0
     or sourceX + CELL > host.sourceW or sourceY + CELL > host.sourceH then
    return false
  end

  host.cellQuad:setViewport(sourceX, sourceY, CELL, CELL,
                            host.sourceW, host.sourceH)
  local metrics = proj:cellMetrics(cx * CELL + ox, cy * CELL + oy, CELL, 0)
  local padX = math.max(1.0, math.abs(proj.shear or 0) * CELL * (proj.scale or 1) * 0.75)
  local padY = math.max(0.6, (proj.scale or 1) * 0.20)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(host.source, host.cellQuad,
                     metrics.x - padX, metrics.y - padY,
                     0,
                     (metrics.width + padX * 2) / CELL,
                     (metrics.height + padY * 2) / CELL)
  return true
end

local function drawVegetationBillboard(host, proj, wx0, wx1, sourceY, baselineY, baseZ)
  local runW = wx1 - wx0
  if runW <= 0 then return false end
  local sx = wx0 - proj.camX
  local sy = sourceY - proj.bgY
  if sx < 0 or sy < 0 or sx + runW > host.sourceW or sy + CELL > host.sourceH then
    return false
  end

  host.cellQuad:setViewport(sx, sy, runW, CELL, host.sourceW, host.sourceH)
  local localY = baselineY - proj.bgY
  local depth = proj:depthScale(localY)
  local centerX, groundY = proj:projectTerrain(wx0 + runW * 0.5, baselineY, baseZ)
  local screenW = runW * depth * proj.scale * 1.10
  local screenH = CELL * proj.scale * 1.08
  love.graphics.setColor(1, 1, 1, 0.97)
  love.graphics.draw(host.source, host.cellQuad,
                     centerX - screenW * 0.5,
                     groundY - screenH,
                     0, screenW / runW, screenH / CELL)

  -- A second, smaller crown sample breaks the straight billboard top edge and
  -- keeps the silhouette closer to a layered HD-2D tree line than a flat card.
  local crownW = screenW * 0.76
  local crownH = screenH * 0.42
  love.graphics.setColor(1, 1, 1, 0.92)
  love.graphics.draw(host.source, host.cellQuad,
                     centerX - crownW * 0.5,
                     groundY - screenH - crownH * 0.40,
                     0, crownW / runW, crownH / CELL)
  return true
end

local baseDrawRow = relief.drawRow
relief.drawRow = function(self, host, ctx, proj, map, ox, oy, cy, x0, x1)
  ox, oy = ox or 0, oy or 0

  -- Overscan only solid footprints; this never changes map collision or source
  -- data and it remains inside the terrain painter row.
  for cx = x0, x1 do
    local material = MaterialClassifier.classify(map, cx, cy)
    if material.kind == "solid" then
      drawPolishMask(host, ctx, proj, map, cx, cy, ox, oy)
    end
  end

  local drawn = baseDrawRow(self, host, ctx, proj, map, ox, oy, cy, x0, x1)

  -- Emit one billboard per contiguous exposed vegetation run after the low
  -- pedestal/canopy geometry has established its contact plane.
  local cx = x0
  while cx <= x1 do
    local material = MaterialClassifier.classify(map, cx, cy)
    if material.family == "vegetation"
       and MaterialClassifier.frontExposed(map, cx, cy) then
      local startX, endX = cx, cx
      while endX + 1 <= x1 do
        local nextMat = MaterialClassifier.classify(map, endX + 1, cy)
        if nextMat.family ~= "vegetation"
           or nextMat.massId ~= material.massId
           or not MaterialClassifier.frontExposed(map, endX + 1, cy) then break end
        endX = endX + 1
      end
      local fullHeight = MaterialClassifier.reliefHeight(material, proj.relief)
      local pedestal = fullHeight * 0.40
      drawVegetationBillboard(host, proj,
                              startX * CELL + ox,
                              (endX + 1) * CELL + ox,
                              cy * CELL + oy,
                              (cy + 1) * CELL + oy + 0.04,
                              pedestal * 0.18)
      cx = endX + 1
    else
      cx = cx + 1
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
  return drawn
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
  -- World-only atmosphere deliberately happens before Gen1Recomp composites
  -- dialog boxes/menus. The focus band follows the player's projected ground
  -- baseline when the full world context is available, so gameplay readability
  -- stays sharp even while DEPTH/CINEMA soften distant scenery.
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