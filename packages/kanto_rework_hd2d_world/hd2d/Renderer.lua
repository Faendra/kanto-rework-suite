local Renderer = {}
Renderer.__index = Renderer

local CELL = 16
local STRIP = 4
local MARGIN_CELLS = 2

local OUTDOOR_TILESETS = {
  OVERWORLD = true,
  FOREST = true,
  SHIP_PORT = true,
  PLATEAU = true,
}

local function finite(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function normalizeColor(c, fallback)
  if type(c) ~= "table" then return fallback end
  local r, g, b = c[1], c[2], c[3]
  if not (finite(r) and finite(g) and finite(b)) then return fallback end
  if r > 1 or g > 1 or b > 1 then
    r, g, b = r / 255, g / 255, b / 255
  end
  return r, g, b
end

local function colorTriple(c, fallback)
  local r, g, b = normalizeColor(c, fallback)
  if type(r) == "table" then
    return fallback[1], fallback[2], fallback[3]
  end
  return r, g, b
end

local function mix(a, b, t)
  return a + (b - a) * t
end

local function smooth01(t)
  t = clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end

local function mapTileset(map)
  return map and map.def and map.def.tileset or nil
end

function Renderer.new(Projection, MaterialClassifier)
  return setmetatable({
    Projection = Projection,
    MaterialClassifier = MaterialClassifier,
    level = 0,
    elapsed = 0,
    source = nil,
    output = nil,
    sourceW = 0,
    sourceH = 0,
    outputW = 0,
    outputH = 0,
    stripQuad = nil,
    cellQuad = nil,
    lastFxWaterAnchors = 0,
    lastOutdoorBackdrop = false,
    lastBackdropBands = 0,
  }, Renderer)
end

function Renderer:available()
  return love ~= nil
     and love.graphics ~= nil
     and type(love.graphics.newCanvas) == "function"
     and type(love.graphics.newQuad) == "function"
end

function Renderer:update(dt, level)
  self.level = tonumber(level) or 0
  self.elapsed = self.elapsed + (tonumber(dt) or 0)
end

local function release(obj)
  if obj and obj.release then pcall(obj.release, obj) end
end

function Renderer:invalidate()
  release(self.source)
  release(self.output)
  release(self.stripQuad)
  release(self.cellQuad)
  self.source, self.output = nil, nil
  self.stripQuad, self.cellQuad = nil, nil
  self.sourceW, self.sourceH = 0, 0
  self.outputW, self.outputH = 0, 0
  self.lastFxWaterAnchors = 0
  self.lastOutdoorBackdrop = false
  self.lastBackdropBands = 0
end

function Renderer:ensureCanvases(ctx)
  local vw = math.max(1, math.floor(ctx.vw or 1))
  local vh = math.max(1, math.floor(ctx.vh or 1))
  local ow = math.max(1, math.floor(ctx.width or 1))
  local oh = math.max(1, math.floor(ctx.height or 1))

  if not self.source or self.sourceW ~= vw or self.sourceH ~= vh then
    release(self.source)
    release(self.stripQuad)
    release(self.cellQuad)
    self.source = love.graphics.newCanvas(vw, vh)
    self.source:setFilter("nearest", "nearest")
    self.sourceW, self.sourceH = vw, vh
    self.stripQuad = love.graphics.newQuad(0, 0, vw, math.min(STRIP, vh), vw, vh)
    self.cellQuad = love.graphics.newQuad(0, 0, math.min(CELL, vw),
                                          math.min(CELL, vh), vw, vh)
  end

  if not self.output or self.outputW ~= ow or self.outputH ~= oh then
    release(self.output)
    self.output = love.graphics.newCanvas(ow, oh)
    self.output:setFilter("nearest", "nearest")
    self.outputW, self.outputH = ow, oh
  end
end

function Renderer:drawTerrainSource(ctx)
  local state = ctx.state
  local map = state and state.map
  if not (map and map.renderer and ctx.cam) then return false end

  love.graphics.push("all")
  love.graphics.setCanvas(self.source)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)

  local cam = ctx.cam
  local bgY = ctx.bgY or cam.y
  map.renderer:drawBorderFill(cam.x, bgY, ctx.vw, ctx.vh)
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

function Renderer:drawGroundStrips(proj)
  love.graphics.setColor(1, 1, 1, 1)
  local y = 0
  while y < self.sourceH do
    local h = math.min(STRIP, self.sourceH - y)
    self.stripQuad:setViewport(0, y, self.sourceW, h, self.sourceW, self.sourceH)
    local centerX, sy0, sy1, depth = proj:stripMetrics(y, y + h)
    local sx = depth * proj.scale
    local sy = (sy1 - sy0) / h
    local dx = centerX - self.sourceW * sx * 0.5
    love.graphics.draw(self.source, self.stripQuad, dx, sy0, 0, sx, sy)
    y = y + h
  end
end

function Renderer:paletteWallColor(ctx, map, alpha, factor)
  local fallback = { 0.12, 0.14, 0.16 }
  local palette = ctx.paletteFor and ctx.paletteFor(map) or nil
  local darkest = type(palette) == "table" and palette[#palette] or nil
  local r, g, b = normalizeColor(darkest, fallback)
  if type(r) == "table" then r, g, b = fallback[1], fallback[2], fallback[3] end
  factor = factor or 0.72
  return r * factor, g * factor, b * factor, alpha or 0.88
end

-- Fill only the projection space that the terrain cannot cover. Outdoor maps
-- get a restrained palette-derived atmospheric horizon; interiors/caves keep
-- a dark neutral surround. This is context-derived from the Gen I tileset,
-- never a map-id profile, and therefore cannot accidentally paint a sky inside
-- a building or cavern.
function Renderer:drawBackdrop(ctx, proj)
  local map = ctx.state and ctx.state.map
  local tileset = mapTileset(map)
  local palette = ctx.paletteFor and ctx.paletteFor(map) or nil
  self.lastOutdoorBackdrop = OUTDOOR_TILESETS[tileset] == true
  self.lastBackdropBands = 0

  if not self.lastOutdoorBackdrop then
    local fallback = { 0.035, 0.045, 0.055 }
    local darkest = type(palette) == "table" and palette[#palette] or nil
    local r, g, b = colorTriple(darkest, fallback)
    love.graphics.clear(clamp(r * 0.34, 0.018, 0.12),
                        clamp(g * 0.36, 0.020, 0.13),
                        clamp(b * 0.40, 0.024, 0.15), 1)
    return
  end

  local fallbackLight = { 0.70, 0.78, 0.80 }
  local fallbackMid = { 0.43, 0.53, 0.50 }
  local light = type(palette) == "table" and (palette[2] or palette[1]) or nil
  local mid = type(palette) == "table" and (palette[3] or palette[2]) or nil
  local lr, lg, lb = colorTriple(light, fallbackLight)
  local mr, mg, mb = colorTriple(mid, fallbackMid)

  -- Blend toward a cool neutral rather than inventing a saturated blue sky;
  -- this keeps Red/Blue/Yellow palettes recognizable while creating the air
  -- separation expected from an HD-2D diorama.
  local cool = { 0.72, 0.79, 0.82 }
  local haze = { 0.52, 0.61, 0.62 }
  local intensity = 0.34 + clamp((self.level - 1) * 0.04, 0, 0.08)
  local topR = mix(lr, cool[1], intensity)
  local topG = mix(lg, cool[2], intensity)
  local topB = mix(lb, cool[3], intensity)
  local horR = mix(mr, haze[1], 0.38)
  local horG = mix(mg, haze[2], 0.38)
  local horB = mix(mb, haze[3], 0.38)

  love.graphics.clear(topR, topG, topB, 1)

  local horizonY = clamp(math.floor((proj.top or 0) + proj.scale * 5 + 0.5),
                         1, self.outputH)
  local bands = 6
  for i = 1, bands do
    local t = smooth01((i - 1) / math.max(1, bands - 1))
    local r = mix(topR, horR, t)
    local g = mix(topG, horG, t)
    local b = mix(topB, horB, t)
    local y0 = math.floor((i - 1) * horizonY / bands)
    local y1 = math.ceil(i * horizonY / bands)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", 0, y0, self.outputW, math.max(1, y1 - y0))
    self.lastBackdropBands = self.lastBackdropBands + 1
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function Renderer:visibleCellRange(map, proj)
  local x0 = math.floor(proj.camX / CELL) - MARGIN_CELLS
  local y0 = math.floor(proj.bgY / CELL) - MARGIN_CELLS
  local x1 = math.ceil((proj.camX + proj.vw) / CELL) + MARGIN_CELLS
  local y1 = math.ceil((proj.bgY + proj.vh) / CELL) + MARGIN_CELLS
  x0 = math.max(0, x0)
  y0 = math.max(0, y0)
  x1 = math.min((map.widthCells or 0) - 1, x1)
  y1 = math.min((map.heightCells or 0) - 1, y1)
  return x0, y0, x1, y1
end

function Renderer:drawSolidRelief(ctx, proj)
  local map = ctx.state and ctx.state.map
  if not map then return end
  local x0, y0, x1, y1 = self:visibleCellRange(map, proj)
  if x1 < x0 or y1 < y0 then return end

  local classifier = self.MaterialClassifier
  local lift = proj.relief
  local wallR, wallG, wallB, wallA = self:paletteWallColor(ctx, map, 0.90, 0.66)
  local sideR, sideG, sideB, sideA = self:paletteWallColor(ctx, map, 0.82, 0.54)

  for cy = y0, y1 do
    for cx = x0, x1 do
      local material = classifier.classify(map, cx, cy)
      if material.kind == "solid" then
        local height = classifier.reliefHeight(material, lift)
        local wx, wy = cx * CELL, cy * CELL

        if classifier.frontExposed(map, cx, cy) then
          local ax, ay = proj:projectTerrain(wx, wy + CELL, 0)
          local bx, by = proj:projectTerrain(wx + CELL, wy + CELL, 0)
          local tax, tay = proj:projectTerrain(wx, wy + CELL, height)
          local tbx, tby = proj:projectTerrain(wx + CELL, wy + CELL, height)
          love.graphics.setColor(wallR, wallG, wallB, wallA)
          love.graphics.polygon("fill", tax, tay, tbx, tby, bx, by, ax, ay)
        end

        if classifier.sideExposed(map, cx, cy, 1) then
          local ax, ay = proj:projectTerrain(wx + CELL, wy, 0)
          local bx, by = proj:projectTerrain(wx + CELL, wy + CELL, 0)
          local tax, tay = proj:projectTerrain(wx + CELL, wy, height)
          local tbx, tby = proj:projectTerrain(wx + CELL, wy + CELL, height)
          love.graphics.setColor(sideR, sideG, sideB, sideA)
          love.graphics.polygon("fill", tax, tay, tbx, tby, bx, by, ax, ay)
        end

        local sx = wx - proj.camX
        local sy = wy - proj.bgY
        if sx >= 0 and sy >= 0
           and sx + CELL <= self.sourceW and sy + CELL <= self.sourceH then
          self.cellQuad:setViewport(sx, sy, CELL, CELL, self.sourceW, self.sourceH)
          local metrics = proj:cellMetrics(wx, wy, CELL, height)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(self.source, self.cellQuad, metrics.x, metrics.y,
                             0, metrics.width / CELL, metrics.height / CELL)
        end
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function actorPose(actor)
  if not actor or type(actor.pose) ~= "function" then return nil end
  local ok, sprite, px, py, facing, phase, flip, hopping = pcall(actor.pose, actor)
  if not ok or not sprite or not finite(px) or not finite(py) then return nil end
  local basePx = finite(actor.px) and actor.px or px
  local basePy = finite(actor.py) and actor.py or py
  return {
    actor = actor, sprite = sprite, px = px, py = py,
    basePx = basePx, basePy = basePy,
    facing = facing, phase = phase, flip = flip, hopping = hopping,
  }
end

function Renderer:collectActors(state)
  local out = {}
  for _, e in ipairs(state.entities or {}) do
    if not ((state.flyAnim or state.flyArrive or state.playerHidden)
            and e == state.player) then
      local row = actorPose(e)
      if row then out[#out + 1] = row end
    end
  end
  for _, g in ipairs(state.ghosts or {}) do
    local row = actorPose(g.npc)
    if row then
      row.ox, row.oy = g.ox or 0, g.oy or 0
      out[#out + 1] = row
    end
  end
  table.sort(out, function(a, b)
    local ay = a.basePy + (a.oy or 0)
    local by = b.basePy + (b.oy or 0)
    if ay ~= by then return ay < by end
    return tostring(a.actor.id or "") < tostring(b.actor.id or "")
  end)
  return out
end

function Renderer:drawShadow(proj, row, surfaceZ)
  surfaceZ = tonumber(surfaceZ) or 0
  local wx = row.basePx + (row.ox or 0) + 8
  local wy = row.basePy + (row.oy or 0) + 16
  local sx, sy, depth = proj:projectWorld(wx, wy, surfaceZ)
  local lift = row.hopping and math.max(0, row.basePy - row.py) or 0
  local alpha = clamp(0.18 - lift * 0.007, 0.09, 0.18)
  local spread = 1 + math.min(lift, 12) * 0.018
  love.graphics.setColor(0, 0, 0, alpha)
  love.graphics.ellipse("fill", sx, sy - proj.scale * 0.7,
                        5.2 * proj.scale * depth * spread,
                        1.7 * proj.scale * spread)
end

function Renderer:drawActor(proj, row, surfaceZ)
  local sprite = row.sprite
  if type(sprite.getPoseGeometry) ~= "function"
     or type(sprite.resolveImage) ~= "function" then return end
  local okGeom, geom = pcall(sprite.getPoseGeometry, sprite, row.facing,
                             row.phase, row.flip)
  local okImage, image = pcall(sprite.resolveImage, sprite)
  if not okGeom or not okImage or not geom or not image then return end

  surfaceZ = tonumber(surfaceZ) or 0
  local wx = row.px + (row.ox or 0) + 8
  local wy
  local lift = 0
  if row.hopping then
    wy = row.basePy + (row.oy or 0) + 12
    lift = math.max(0, row.basePy - row.py)
  else
    wy = row.py + (row.oy or 0) + 12
  end
  local sx, sy = proj:projectWorld(wx, wy, surfaceZ + lift)
  local scale = proj.scale
  local x = sx - (geom.anchorX or geom.width * 0.5) * scale
  local y = sy - (geom.anchorY or geom.height) * scale
  love.graphics.setColor(1, 1, 1, 1)
  if geom.mirror then
    love.graphics.draw(image, geom.quad,
                       x + geom.width * scale, y, 0, -scale, scale)
  else
    love.graphics.draw(image, geom.quad, x, y, 0, scale, scale)
  end
end

function Renderer:drawActors(ctx, proj)
  local rows = self:collectActors(ctx.state)
  for _, row in ipairs(rows) do self:drawShadow(proj, row, 0) end
  for _, row in ipairs(rows) do self:drawActor(proj, row, 0) end
end

function Renderer:drawWaterLight(ctx, proj)
  if self.level < 2 then return end
  local map = ctx.state and ctx.state.map
  if not map then return end
  local p = ctx.state.player
  if not p then return end
  local phase = (math.sin(self.elapsed * 1.5) + 1) * 0.5
  local radius = 5
  local cx0, cy0 = p.cellX or 0, p.cellY or 0
  local waterZ = 0
  if type(self.waterSurfaceZ) == "function" then
    local ok, value = pcall(self.waterSurfaceZ, self)
    if ok and finite(value) then waterZ = value end
  end
  love.graphics.setColor(1, 1, 1, 0.025 + phase * 0.025)
  for cy = cy0 - radius, cy0 + radius do
    for cx = cx0 - radius, cx0 + radius do
      local material = self.MaterialClassifier.classify(map, cx, cy)
      if material.kind == "water" then
        local wx, wy = cx * CELL, cy * CELL
        local a = proj:cellMetrics(wx, wy, CELL, waterZ)
        love.graphics.rectangle("fill", a.x, a.y + a.height * 0.62,
                                a.width, math.max(1, proj.scale * 0.55))
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function Renderer:surfaceZForWorld(map, wx, wy)
  if not map or not self.MaterialClassifier then return 0 end
  local cx = math.floor((tonumber(wx) or 0) / CELL)
  -- Foot/baseline anchors are commonly placed exactly on a cell's south
  -- boundary. Bias one epsilon north so they resolve to the cell they stand on.
  local cy = math.floor(((tonumber(wy) or 0) - 0.001) / CELL)
  local material = self.MaterialClassifier.classify(map, cx, cy)
  if material.kind == "water" and type(self.waterSurfaceZ) == "function" then
    local ok, value = pcall(self.waterSurfaceZ, self)
    if ok and finite(value) then return value end
  end
  return 0
end

function Renderer:drawWorld(ctx)
  if not self:available() then return nil end
  if type(ctx) ~= "table" or not ctx.state or not ctx.state.map
     or not ctx.cam or not ctx.vw or not ctx.vh or not ctx.width or not ctx.height then
    return nil
  end

  self:ensureCanvases(ctx)
  if not self:drawTerrainSource(ctx) then return nil end

  local proj = self.Projection.new(ctx, math.max(1, self.level))
  love.graphics.push("all")
  love.graphics.setCanvas(self.output)
  self:drawBackdrop(ctx, proj)
  self:drawGroundStrips(proj)
  self:drawSolidRelief(ctx, proj)
  self:drawWaterLight(ctx, proj)
  self:drawActors(ctx, proj)
  self.lastFxWaterAnchors = 0
  if type(ctx.drawFx) == "function" then
    local map = ctx.state.map
    ctx.drawFx(function(wx, wy)
      local z = self:surfaceZForWorld(map, wx, wy)
      if z < 0 then self.lastFxWaterAnchors = self.lastFxWaterAnchors + 1 end
      local sx, sy = proj:projectWorld(wx, wy, z)
      return sx, sy
    end, proj.scale)
  end
  love.graphics.setCanvas()
  love.graphics.pop()
  return self.output
end

return Renderer