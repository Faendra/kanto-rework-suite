local SceneRenderer = {}
SceneRenderer.__index = SceneRenderer

local CELL = 16
local CAPTURE_PAD = CELL * 3

local OUTDOOR_TILESETS = {
  OVERWORLD = true,
  FOREST = true,
  SHIP_PORT = true,
  PLATEAU = true,
}

local COLORS = {
  skyTop = { 0.63, 0.76, 0.82 },
  skyHorizon = { 0.79, 0.82, 0.72 },
  ground = { 0.52, 0.64, 0.42 },
  water = { 0.28, 0.53, 0.68 },
  waterSide = { 0.15, 0.32, 0.43 },
  wall = { 0.72, 0.72, 0.64 },
  wallSide = { 0.53, 0.55, 0.49 },
  roof = { 0.38, 0.37, 0.31 },
  roofFar = { 0.29, 0.30, 0.27 },
  civicWall = { 0.72, 0.76, 0.69 },
  civicRoof = { 0.31, 0.39, 0.37 },
  door = { 0.72, 0.46, 0.13 },
  window = { 0.50, 0.67, 0.66 },
  trunk = { 0.34, 0.23, 0.13 },
  canopy = { 0.20, 0.43, 0.22 },
  canopyMid = { 0.28, 0.54, 0.27 },
  canopyTop = { 0.39, 0.64, 0.32 },
  rock = { 0.58, 0.61, 0.56 },
  rockSide = { 0.37, 0.40, 0.38 },
  shadow = { 0.025, 0.030, 0.035 },
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function finite(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function setColor(c, alpha, mul)
  mul = mul or 1
  love.graphics.setColor(clamp(c[1] * mul, 0, 1),
                         clamp(c[2] * mul, 0, 1),
                         clamp(c[3] * mul, 0, 1), alpha or 1)
end

local function mix(a, b, t)
  return a + (b - a) * t
end

local function drawPoly(points)
  love.graphics.polygon("fill", points)
end

local function release(obj)
  if obj and obj.release then pcall(obj.release, obj) end
end

local function mapTileset(map)
  return map and map.def and map.def.tileset or nil
end

local function sceneKey(map, id)
  return tostring(map) .. ":" .. tostring(id)
end

local function worldCellKey(x, y)
  return string.format("%.4f:%.4f", x, y)
end

local function actorPose(actor)
  if not actor or type(actor.pose) ~= "function" then return nil end
  local ok, sprite, px, py, facing, phase, flip, hopping = pcall(actor.pose, actor)
  if not ok or not sprite or not finite(px) or not finite(py) then return nil end
  return {
    actor = actor,
    sprite = sprite,
    px = px,
    py = py,
    basePx = finite(actor.px) and actor.px or px,
    basePy = finite(actor.py) and actor.py or py,
    facing = facing,
    phase = phase,
    flip = flip,
    hopping = hopping == true,
  }
end

function SceneRenderer.new(Projection, MaterialClassifier)
  return setmetatable({
    Projection = Projection,
    MaterialClassifier = MaterialClassifier,
    level = 0,
    elapsed = 0,
    source = nil,
    output = nil,
    mesh = nil,
    sourceW = 0,
    sourceH = 0,
    outputW = 0,
    outputH = 0,
    sourceCamX = 0,
    sourceCamY = 0,
    lastGroundCells = 0,
    lastWaterCells = 0,
    lastStructures = 0,
    lastVegetation = 0,
    lastBoundaries = 0,
    lastActors = 0,
    lastCommands = 0,
    lastFx = 0,
    lastOutdoor = false,
    lastTexturedGround = 0,
  }, SceneRenderer)
end

function SceneRenderer:available()
  return love ~= nil and love.graphics ~= nil
     and type(love.graphics.newCanvas) == "function"
end

function SceneRenderer:update(dt, level)
  self.level = tonumber(level) or 0
  self.elapsed = self.elapsed + (tonumber(dt) or 0)
end

function SceneRenderer:invalidate()
  release(self.mesh)
  release(self.source)
  release(self.output)
  self.mesh, self.source, self.output = nil, nil, nil
  self.sourceW, self.sourceH = 0, 0
  self.outputW, self.outputH = 0, 0
end

function SceneRenderer:resetMetrics()
  self.lastGroundCells = 0
  self.lastWaterCells = 0
  self.lastStructures = 0
  self.lastVegetation = 0
  self.lastBoundaries = 0
  self.lastActors = 0
  self.lastCommands = 0
  self.lastFx = 0
  self.lastTexturedGround = 0
end

function SceneRenderer:ensureCanvases(ctx)
  local sw = math.max(1, math.floor((tonumber(ctx.vw) or 160) + CAPTURE_PAD * 2))
  local sh = math.max(1, math.floor((tonumber(ctx.vh) or 144) + CAPTURE_PAD * 2))
  local ow = math.max(1, math.floor(tonumber(ctx.width) or 1))
  local oh = math.max(1, math.floor(tonumber(ctx.height) or 1))

  if not self.source or self.sourceW ~= sw or self.sourceH ~= sh then
    release(self.source)
    self.source = love.graphics.newCanvas(sw, sh)
    if self.source.setFilter then self.source:setFilter("nearest", "nearest") end
    self.sourceW, self.sourceH = sw, sh
  end

  if not self.output or self.outputW ~= ow or self.outputH ~= oh then
    release(self.output)
    self.output = love.graphics.newCanvas(ow, oh)
    if self.output.setFilter then self.output:setFilter("nearest", "nearest") end
    self.outputW, self.outputH = ow, oh
  end

  if not self.mesh and type(love.graphics.newMesh) == "function" then
    local ok, mesh = pcall(love.graphics.newMesh, {
      { 0, 0, 0, 0, 1, 1, 1, 1 },
      { 1, 0, 1, 0, 1, 1, 1, 1 },
      { 1, 1, 1, 1, 1, 1, 1, 1 },
      { 0, 1, 0, 1, 1, 1, 1, 1 },
    }, "fan", "dynamic")
    if ok and mesh then self.mesh = mesh end
  end
end

local function fallbackGroundColor(ctx, map)
  local fallback = COLORS.ground
  local palette = ctx.paletteFor and ctx.paletteFor(map) or nil
  local c = type(palette) == "table" and (palette[2] or palette[1]) or nil
  if type(c) ~= "table" then return fallback[1], fallback[2], fallback[3] end
  local r, g, b = tonumber(c[1]), tonumber(c[2]), tonumber(c[3])
  if not r or not g or not b then return fallback[1], fallback[2], fallback[3] end
  if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
  return mix(r, fallback[1], 0.42),
         mix(g, fallback[2], 0.42),
         mix(b, fallback[3], 0.42)
end

function SceneRenderer:captureTerrain(ctx)
  local state = ctx.state
  local map = state and state.map
  if not (map and map.renderer and ctx.cam) then return false end

  self.sourceCamX = (tonumber(ctx.cam.x) or 0) - CAPTURE_PAD
  self.sourceCamY = (tonumber(ctx.bgY) or tonumber(ctx.cam.y) or 0) - CAPTURE_PAD
  self.lastOutdoor = OUTDOOR_TILESETS[mapTileset(map)] == true

  love.graphics.push("all")
  love.graphics.setCanvas(self.source)
  if map.renderer.drawBorderFill then
    map.renderer:drawBorderFill(self.sourceCamX, self.sourceCamY,
                                self.sourceW, self.sourceH)
  end
  if self.lastOutdoor then
    local r, g, b = fallbackGroundColor(ctx, map)
    love.graphics.clear(r, g, b, 1)
  end

  love.graphics.setColor(1, 1, 1, 1)
  map.renderer:draw(self.sourceCamX, self.sourceCamY,
                    self.sourceW, self.sourceH)
  for _, nb in ipairs(state.neighbors or {}) do
    if nb.map and nb.map.renderer and nb.map.renderer.drawMapOnly then
      nb.map.renderer:drawMapOnly(self.sourceCamX - (nb.ox or 0),
                                  self.sourceCamY - (nb.oy or 0),
                                  self.sourceW, self.sourceH)
    end
  end

  love.graphics.setCanvas()
  love.graphics.pop()
  return true
end

function SceneRenderer:scenes(state)
  local out = {}
  if state and state.map then
    out[#out + 1] = { map = state.map, ox = 0, oy = 0, primary = true }
  end
  for _, nb in ipairs(state and state.neighbors or {}) do
    if nb.map then
      out[#out + 1] = {
        map = nb.map,
        ox = tonumber(nb.ox) or 0,
        oy = tonumber(nb.oy) or 0,
        primary = false,
      }
    end
  end
  return out
end

local function localBounds(renderer, scene)
  local map = scene.map
  local x0 = math.floor((renderer.sourceCamX - scene.ox) / CELL) - 1
  local y0 = math.floor((renderer.sourceCamY - scene.oy) / CELL) - 1
  local x1 = math.ceil((renderer.sourceCamX + renderer.sourceW - scene.ox) / CELL) + 1
  local y1 = math.ceil((renderer.sourceCamY + renderer.sourceH - scene.oy) / CELL) + 1
  x0 = math.max(0, x0)
  y0 = math.max(0, y0)
  x1 = math.min((tonumber(map.widthCells) or 0) - 1, x1)
  y1 = math.min((tonumber(map.heightCells) or 0) - 1, y1)
  return x0, y0, x1, y1
end

local function donorCell(classifier, map, cx, cy)
  local grassCandidate
  for radius = 1, 3 do
    for dy = -radius, radius do
      for dx = -radius, radius do
        if math.abs(dx) == radius or math.abs(dy) == radius then
          local nx, ny = cx + dx, cy + dy
          local m = classifier.classify(map, nx, ny)
          if m.kind == "ground" then return nx, ny end
          if not grassCandidate and m.kind == "grass" then
            grassCandidate = { nx, ny }
          end
        end
      end
    end
  end
  if grassCandidate then return grassCandidate[1], grassCandidate[2] end
  return nil
end

local function sampleRect(renderer, scene, cx, cy, material)
  local sxCell, syCell = cx, cy
  if material and material.kind == "solid" then
    local dx, dy = donorCell(renderer.MaterialClassifier, scene.map, cx, cy)
    if not dx then return nil end
    sxCell, syCell = dx, dy
  end
  local sx = sxCell * CELL + scene.ox - renderer.sourceCamX
  local sy = syCell * CELL + scene.oy - renderer.sourceCamY
  if sx < 0 or sy < 0 or sx + CELL > renderer.sourceW or sy + CELL > renderer.sourceH then
    return nil
  end
  return sx, sy, CELL, CELL
end

function SceneRenderer:drawTexturedQuad(proj, x, y, z, rect, fallback)
  local points = proj:cellPolygon(x, y, z)
  if not (self.mesh and rect and self.mesh.setVertices and self.mesh.setTexture) then
    setColor(fallback or COLORS.ground)
    drawPoly(points)
    return false
  end

  local sx, sy, sw, sh = rect[1], rect[2], rect[3], rect[4]
  local u0, v0 = sx / self.sourceW, sy / self.sourceH
  local u1, v1 = (sx + sw) / self.sourceW, (sy + sh) / self.sourceH
  local vertices = {
    { points[1], points[2], u0, v0, 1, 1, 1, 1 },
    { points[3], points[4], u1, v0, 1, 1, 1, 1 },
    { points[5], points[6], u1, v1, 1, 1, 1, 1 },
    { points[7], points[8], u0, v1, 1, 1, 1, 1 },
  }
  local ok = pcall(function()
    self.mesh:setVertices(vertices)
    self.mesh:setTexture(self.source)
  end)
  if not ok then
    setColor(fallback or COLORS.ground)
    drawPoly(points)
    return false
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.mesh)
  return true
end

local function southWall(proj, x0, x1, y, z0, z1)
  local ax, ay = proj:cell(x0, y, z0)
  local bx, by = proj:cell(x1, y, z0)
  local cx, cy = proj:cell(x1, y, z1)
  local dx, dy = proj:cell(x0, y, z1)
  return { ax, ay, bx, by, cx, cy, dx, dy }
end

local function eastWall(proj, x, y0, y1, z0, z1)
  local ax, ay = proj:cell(x, y0, z0)
  local bx, by = proj:cell(x, y1, z0)
  local cx, cy = proj:cell(x, y1, z1)
  local dx, dy = proj:cell(x, y0, z1)
  return { ax, ay, bx, by, cx, cy, dx, dy }
end

local function drawSouthPanel(proj, x0, x1, y, z0, z1, color)
  setColor(color)
  drawPoly(southWall(proj, x0, x1, y + 0.002, z0, z1))
end

local function drawEastPanel(proj, x, y0, y1, z0, z1, color)
  setColor(color)
  drawPoly(eastWall(proj, x + 0.002, y0, y1, z0, z1))
end

local function findDoorX(classifier, map, mass)
  local cy = mass.maxY
  for cx = mass.minX, mass.maxX do
    if classifier.isTraversalThreshold(map, cx, cy + 1) then
      return cx + 0.5
    end
  end
  return (mass.minX + mass.maxX + 1) * 0.5
end

local function drawStructureShadow(proj, x0, y0, x1, y1, level)
  local reach = ({ 0.18, 0.25, 0.32 })[level] or 0.22
  setColor(COLORS.shadow, 0.14)
  drawPoly(proj:quad(x0 + reach, y0 + reach * 0.72,
                     x1 + reach, y1 + reach * 0.72, 0.006))
end

function SceneRenderer:drawStructure(proj, cmd)
  local mass = cmd.mass
  local ox = cmd.scene.ox / CELL
  local oy = cmd.scene.oy / CELL
  local x0 = mass.minX + ox
  local x1 = mass.maxX + 1 + ox
  local y0 = mass.minY + oy
  local y1 = mass.maxY + 1 + oy
  local spanX = mass.spanX or (x1 - x0)
  local civic = spanX >= 5 or (mass.spanY or 0) >= 4
  local levelScale = ({ 0.92, 1.00, 1.08 })[proj.level] or 1
  local wallH = (civic and 0.74 or 0.82) * levelScale
  local ridgeH = wallH + (civic and 0.36 or 0.48) * levelScale
  local ridgeY = y0 + (y1 - y0) * 0.48
  local wallColor = civic and COLORS.civicWall or COLORS.wall
  local roofColor = civic and COLORS.civicRoof or COLORS.roof

  drawStructureShadow(proj, x0, y0, x1, y1, proj.level)
  setColor(COLORS.roofFar)
  local n0x, n0y = proj:cell(x0 - 0.08, y0 - 0.05, wallH)
  local n1x, n1y = proj:cell(x1 + 0.08, y0 - 0.05, wallH)
  local r1x, r1y = proj:cell(x1 + 0.08, ridgeY, ridgeH)
  local r0x, r0y = proj:cell(x0 - 0.08, ridgeY, ridgeH)
  drawPoly({ n0x, n0y, n1x, n1y, r1x, r1y, r0x, r0y })

  setColor(wallColor)
  drawPoly(southWall(proj, x0, x1, y1, 0, wallH))
  setColor(COLORS.wallSide)
  drawPoly(eastWall(proj, x1, y0, y1, 0, wallH))

  setColor(roofColor)
  local f0x, f0y = proj:cell(x0 - 0.10, y1 + 0.08, wallH)
  local f1x, f1y = proj:cell(x1 + 0.10, y1 + 0.08, wallH)
  local rr1x, rr1y = proj:cell(x1 + 0.08, ridgeY, ridgeH)
  local rr0x, rr0y = proj:cell(x0 - 0.08, ridgeY, ridgeH)
  drawPoly({ rr0x, rr0y, rr1x, rr1y, f1x, f1y, f0x, f0y })

  local e0x, e0y = proj:cell(x1 + 0.085, y0, wallH)
  local e1x, e1y = proj:cell(x1 + 0.085, y1, wallH)
  local erx, ery = proj:cell(x1 + 0.085, ridgeY, ridgeH)
  setColor(COLORS.roofFar, 1, 0.94)
  drawPoly({ e0x, e0y, e1x, e1y, erx, ery })

  local localDoorX = findDoorX(self.MaterialClassifier, cmd.scene.map, mass)
  local doorX = localDoorX + ox
  local doorHalf = 0.26
  local doorH = wallH * 0.62
  drawSouthPanel(proj, doorX - doorHalf, doorX + doorHalf,
                 y1 + 0.006, 0.01, doorH, COLORS.door)

  local function windowAt(cx)
    if math.abs(cx - doorX) < 0.62 then return end
    drawSouthPanel(proj, cx - 0.22, cx + 0.22, y1 + 0.008,
                   wallH * 0.30, wallH * 0.55, COLORS.window)
  end
  if x1 - x0 >= 2.2 then
    windowAt(x0 + 0.62)
    windowAt(x1 - 0.62)
  end

  if love.graphics.setLineWidth and love.graphics.line then
    love.graphics.setLineWidth(math.max(1, proj.tileW * 0.018))
    setColor(COLORS.shadow, 0.28)
    love.graphics.line(f0x, f0y, f1x, f1y)
  end
end

local function drawTrunk(proj, x, y, z0, z1)
  local bx, by = proj:cell(x, y, z0)
  local tx, ty = proj:cell(x, y, z1)
  local half = proj.tileW * 0.045
  setColor(COLORS.trunk)
  drawPoly({ bx - half, by, bx + half, by, tx + half, ty, tx - half, ty })
end

function SceneRenderer:drawVegetation(proj, cmd)
  local x, y = cmd.x, cmd.y
  local cx, cy = x + 0.5, y + 0.5
  local scale = ({ 0.92, 1.00, 1.08 })[proj.level] or 1

  setColor(COLORS.shadow, 0.10)
  drawPoly(proj:quad(x + 0.18, y + 0.18, x + 0.82, y + 0.82, 0.005))
  drawTrunk(proj, cx, cy + 0.05, 0, 0.36 * scale)
  setColor(COLORS.canopy, 1)
  drawPoly(proj:quad(x + 0.08, y + 0.08, x + 0.92, y + 0.92, 0.34 * scale))
  setColor(COLORS.canopyMid, 1)
  drawPoly(proj:quad(x + 0.16, y + 0.16, x + 0.84, y + 0.84, 0.55 * scale))
  setColor(COLORS.canopyTop, 1)
  drawPoly(proj:quad(x + 0.27, y + 0.27, x + 0.73, y + 0.73, 0.73 * scale))
end

function SceneRenderer:drawLowPrism(proj, cmd, height, topColor)
  local x, y = cmd.x, cmd.y
  height = height or 0.16
  setColor(COLORS.shadow, 0.075)
  drawPoly(proj:quad(x + 0.10, y + 0.10, x + 0.94, y + 0.94, 0.004))
  setColor(COLORS.rockSide)
  drawPoly(southWall(proj, x, x + 1, y + 1, 0, height))
  drawPoly(eastWall(proj, x + 1, y, y + 1, 0, height))
  if cmd.rect and self:drawTexturedQuad(proj, x, y, height, cmd.rect, topColor or COLORS.rock) then
    return
  end
  setColor(topColor or COLORS.rock)
  drawPoly(proj:cellPolygon(x, y, height))
end

function SceneRenderer:collectActors(state)
  local out = {}
  for _, actor in ipairs(state.entities or {}) do
    if not ((state.flyAnim or state.flyArrive or state.playerHidden)
            and actor == state.player) then
      local row = actorPose(actor)
      if row then
        row.map = state.map
        row.ox, row.oy = 0, 0
        out[#out + 1] = row
      end
    end
  end
  for _, ghost in ipairs(state.ghosts or {}) do
    local row = actorPose(ghost.npc)
    if row then
      row.map = ghost.map
      row.ox, row.oy = tonumber(ghost.ox) or 0, tonumber(ghost.oy) or 0
      out[#out + 1] = row
    end
  end
  return out
end

local function actorSurfaceZ(classifier, row)
  local map = row.map
  if not map then return 0 end
  local cx = math.floor((row.basePx + 8) / CELL)
  local cy = math.floor((row.basePy + 12) / CELL)
  local m = classifier.classify(map, cx, cy)
  if m.kind == "water" then return -0.12 end
  return 0
end

function SceneRenderer:drawActor(proj, row)
  local sprite = row.sprite
  if not (sprite and type(sprite.getPoseGeometry) == "function"
          and type(sprite.resolveImage) == "function") then return false end
  local okGeom, geometry = pcall(sprite.getPoseGeometry, sprite,
                                  row.facing, row.phase, row.flip)
  local okImg, image = pcall(sprite.resolveImage, sprite)
  if not okGeom or not okImg or not geometry or not geometry.quad or not image then
    return false
  end

  local surfaceZ = actorSurfaceZ(self.MaterialClassifier, row)
  local hop = 0
  if row.hopping then hop = math.max(0, row.basePy - row.py) / CELL end
  local worldX = row.basePx + row.ox + 8
  local worldY = row.basePy + row.oy + 12
  local sx, sy = proj:worldPixel(worldX, worldY, surfaceZ + hop)
  local shadowX, shadowY = proj:worldPixel(worldX, worldY, surfaceZ)
  local s = proj.spriteScale

  love.graphics.setColor(0, 0, 0, 0.17 * clamp(1 - hop * 0.45, 0.45, 1))
  love.graphics.ellipse("fill", shadowX, shadowY + 1,
                        5.5 * s * (1 + hop * 0.10),
                        2.0 * s * (1 + hop * 0.08))

  love.graphics.setColor(1, 1, 1, 1)
  local y = sy - geometry.anchorY * s
  if geometry.mirror then
    local x = sx + (geometry.width - geometry.anchorX) * s
    love.graphics.draw(image, geometry.quad, x, y, 0, -s, s)
  else
    local x = sx - geometry.anchorX * s
    love.graphics.draw(image, geometry.quad, x, y, 0, s, s)
  end
  return true
end

function SceneRenderer:drawBackdrop(ctx, proj)
  local map = ctx.state and ctx.state.map
  if not OUTDOOR_TILESETS[mapTileset(map)] then
    love.graphics.clear(0.045, 0.052, 0.056, 1)
    return
  end

  local bands = 8
  for i = 1, bands do
    local t = (i - 1) / math.max(1, bands - 1)
    local r = mix(COLORS.skyTop[1], COLORS.skyHorizon[1], t)
    local g = mix(COLORS.skyTop[2], COLORS.skyHorizon[2], t)
    local b = mix(COLORS.skyTop[3], COLORS.skyHorizon[3], t)
    local y0 = math.floor((i - 1) * self.outputH / bands)
    local y1 = math.ceil(i * self.outputH / bands)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", 0, y0, self.outputW, math.max(1, y1 - y0))
  end
end

function SceneRenderer:buildScene(ctx, proj)
  local scenes = self:scenes(ctx.state)
  local ground, objects = {}, {}
  local occupied = {}
  local structures = {}

  for _, scene in ipairs(scenes) do
    local x0, y0, x1, y1 = localBounds(self, scene)
    if x1 >= x0 and y1 >= y0 then
      for cy = y0, y1 do
        for cx = x0, x1 do
          local material = self.MaterialClassifier.classify(scene.map, cx, cy)
          if material.kind ~= "void" then
            local wx = cx + scene.ox / CELL
            local wy = cy + scene.oy / CELL
            local key = worldCellKey(wx, wy)
            if not occupied[key] then
              occupied[key] = true
              local rectValues
              local sx, sy, sw, sh = sampleRect(self, scene, cx, cy, material)
              if sx then rectValues = { sx, sy, sw, sh } end
              local z = material.kind == "water" and -0.12 or 0
              ground[#ground + 1] = {
                x = wx, y = wy, z = z,
                scene = scene, cx = cx, cy = cy,
                material = material, rect = rectValues,
              }
              if material.kind == "water" then
                self.lastWaterCells = self.lastWaterCells + 1
              end

              if material.kind == "solid" then
                local mass = self.MaterialClassifier.massInfo(scene.map, cx, cy)
                local family = material.family or "mass"
                if family == "structure" and mass then
                  local sk = sceneKey(scene.map, mass.id)
                  if not structures[sk] then
                    structures[sk] = true
                    objects[#objects + 1] = {
                      kind = "structure",
                      scene = scene,
                      mass = mass,
                      depth = proj:depth(mass.maxX + 1 + scene.ox / CELL,
                                         mass.maxY + 1 + scene.oy / CELL, 0.18),
                    }
                  end
                elseif family == "vegetation" then
                  objects[#objects + 1] = {
                    kind = "vegetation", x = wx, y = wy, scene = scene,
                    depth = proj:depth(wx + 0.5, wy + 0.9, 0.04),
                  }
                else
                  objects[#objects + 1] = {
                    kind = family == "boundary" and "boundary" or "obstacle",
                    x = wx, y = wy, scene = scene, rect = rectValues,
                    depth = proj:depth(wx + 0.5, wy + 0.95, 0.02),
                  }
                end
              end
            end
          end
        end
      end
    end
  end

  for _, row in ipairs(self:collectActors(ctx.state)) do
    local wx = (row.basePx + row.ox + 8) / CELL
    local wy = (row.basePy + row.oy + 12) / CELL
    row.kind = "actor"
    row.depth = proj:depth(wx, wy, 0.11)
    objects[#objects + 1] = row
  end

  table.sort(objects, function(a, b)
    if a.depth ~= b.depth then return a.depth < b.depth end
    local rank = { boundary = 1, obstacle = 1, vegetation = 2, structure = 3, actor = 4 }
    return (rank[a.kind] or 0) < (rank[b.kind] or 0)
  end)
  return ground, objects, scenes
end

function SceneRenderer:sceneForWorldPixel(scenes, wx, wy)
  for _, scene in ipairs(scenes or {}) do
    local lx = wx - scene.ox
    local ly = wy - scene.oy
    if lx >= 0 and ly >= 0
       and lx < (tonumber(scene.map.widthCells) or 0) * CELL
       and ly < (tonumber(scene.map.heightCells) or 0) * CELL then
      return scene, lx, ly
    end
  end
  return nil
end

function SceneRenderer:surfaceZForWorld(scenes, wx, wy)
  local scene, lx, ly = self:sceneForWorldPixel(scenes, wx, wy)
  if not scene then return 0 end
  local m = self.MaterialClassifier.classify(scene.map,
                                              math.floor(lx / CELL),
                                              math.floor(ly / CELL))
  return m.kind == "water" and -0.12 or 0
end

-- Extension point for semantic terrain layers. Base renderer has no vertical
-- terrain faces; TerrainRemaster overrides this to draw only verified ledges.
function SceneRenderer:drawTerrainFaces(proj, ground, scenes)
  return 0
end

function SceneRenderer:drawWorld(ctx)
  if self.level <= 0 then return nil end
  if not (ctx and ctx.state and ctx.state.map and ctx.cam
          and ctx.width and ctx.height and ctx.vw and ctx.vh) then
    return nil
  end
  if not self:available() then return nil end

  self:resetMetrics()
  self:ensureCanvases(ctx)
  if not self:captureTerrain(ctx) then return nil end
  local proj = self.Projection.new(ctx, math.max(1, self.level))
  local ground, objects, scenes = self:buildScene(ctx, proj)

  love.graphics.push("all")
  love.graphics.setCanvas(self.output)
  self:drawBackdrop(ctx, proj)

  for _, cmd in ipairs(ground) do
    local fallback = cmd.material.kind == "water" and COLORS.water or COLORS.ground
    if self:drawTexturedQuad(proj, cmd.x, cmd.y, cmd.z, cmd.rect, fallback) then
      self.lastTexturedGround = self.lastTexturedGround + 1
    end
    if cmd.material.kind == "water" then
      setColor(COLORS.water, 0.07)
      drawPoly(proj:cellPolygon(cmd.x, cmd.y, cmd.z + 0.003))
    end
    self.lastGroundCells = self.lastGroundCells + 1
  end

  -- True terrain faces are composed after every ground tile and before scene
  -- objects. This prevents lower terrace tiles from overpainting a ledge face,
  -- while actors/trees/buildings still occlude the terrain correctly.
  self:drawTerrainFaces(proj, ground, scenes)

  for _, cmd in ipairs(objects) do
    if cmd.kind == "structure" then
      self:drawStructure(proj, cmd)
      self.lastStructures = self.lastStructures + 1
    elseif cmd.kind == "vegetation" then
      self:drawVegetation(proj, cmd)
      self.lastVegetation = self.lastVegetation + 1
    elseif cmd.kind == "boundary" then
      self:drawLowPrism(proj, cmd, 0.18, COLORS.rock)
      self.lastBoundaries = self.lastBoundaries + 1
    elseif cmd.kind == "obstacle" then
      self:drawLowPrism(proj, cmd, 0.14, COLORS.rock)
      self.lastBoundaries = self.lastBoundaries + 1
    elseif cmd.kind == "actor" then
      if self:drawActor(proj, cmd) then self.lastActors = self.lastActors + 1 end
    end
    self.lastCommands = self.lastCommands + 1
  end

  if type(ctx.drawFx) == "function" then
    ctx.drawFx(function(wx, wy)
      return proj:worldPixel(wx, wy, self:surfaceZForWorld(scenes, wx, wy))
    end, proj.spriteScale)
    self.lastFx = self.lastFx + 1
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setCanvas()
  love.graphics.pop()
  return self.output
end

return SceneRenderer
