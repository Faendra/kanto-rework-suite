local BuildingRenderer = {}
BuildingRenderer.__index = BuildingRenderer

local CELL = 16
local unpackValues = unpack or table.unpack

local COLORS = {
  sky = { 0.74, 0.80, 0.76, 1 },
  ground = { 0.57, 0.65, 0.50, 1 },
  pixel = { 1, 1, 1, 1 },
  side = { 0.78, 0.78, 0.74, 1 },
  roofFar = { 0.86, 0.86, 0.82, 1 },
  fascia = { 0.56, 0.56, 0.52, 1 },
}

local function release(obj)
  if obj and obj.release then pcall(obj.release, obj) end
end

local function finite(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function rgba(c, alpha)
  love.graphics.setColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

local function actorPose(actor)
  if not actor or type(actor.pose) ~= "function" then return nil end
  local ok, sprite, px, py, facing, phase, flip, hopping = pcall(actor.pose, actor)
  if not ok or not sprite or not finite(px) or not finite(py) then return nil end
  return {
    kind = "actor", actor = actor, sprite = sprite,
    px = px, py = py,
    basePx = finite(actor.px) and actor.px or px,
    basePy = finite(actor.py) and actor.py or py,
    facing = facing, phase = phase, flip = flip, hopping = hopping == true,
  }
end

local function projectFace(proj, points)
  local out = {}
  for i = 1, #points do
    local p = points[i]
    local x, y = proj:cell(p[1], p[2], p[3])
    out[#out + 1], out[#out + 1] = x, y
  end
  return out
end

function BuildingRenderer.new(Projection, AtlasSource, SceneBuilder)
  return setmetatable({
    Projection = assert(Projection),
    AtlasSource = assert(AtlasSource),
    SceneBuilder = assert(SceneBuilder),
    level = 0,
    mesh = nil,
    output = nil,
    outputW = 0,
    outputH = 0,
    preparedKey = nil,
    prepared = nil,
    atlasCellCache = {},
    atlasRegionCache = {},
    lastMaterialBuilds = 0,
    lastGroundCells = 0,
    lastActors = 0,
    lastBuildings = 0,
    lastDrawCalls = 0,
  }, BuildingRenderer)
end

function BuildingRenderer:available()
  return love and love.graphics
     and type(love.graphics.newCanvas) == "function"
     and type(love.graphics.newMesh) == "function"
end

function BuildingRenderer:update(_, level)
  self.level = tonumber(level) or 0
end

function BuildingRenderer:ensureResources(ctx)
  local w = math.max(1, math.floor(tonumber(ctx.width) or 1))
  local h = math.max(1, math.floor(tonumber(ctx.height) or 1))
  if not self.output or self.outputW ~= w or self.outputH ~= h then
    release(self.output)
    self.output = love.graphics.newCanvas(w, h)
    if self.output.setFilter then self.output:setFilter("nearest", "nearest") end
    self.outputW, self.outputH = w, h
  end
  if not self.mesh then
    self.mesh = love.graphics.newMesh({
      { 0, 0, 0, 0, 1, 1, 1, 1 },
      { 1, 0, 1, 0, 1, 1, 1, 1 },
      { 1, 1, 1, 1, 1, 1, 1, 1 },
      { 0, 1, 0, 1, 1, 1, 1, 1 },
    }, "fan", "dynamic")
  end
end

function BuildingRenderer:drawFace(proj, texture, points, color, uv)
  local poly = projectFace(proj, points)
  color = color or COLORS.pixel
  if not texture then
    rgba(color)
    love.graphics.polygon("fill", unpackValues(poly))
    self.lastDrawCalls = self.lastDrawCalls + 1
    return false
  end

  uv = uv or { 0, 0, 1, 0, 1, 1, 0, 1 }
  self.mesh:setVertices({
    { poly[1], poly[2], uv[1], uv[2], color[1], color[2], color[3], color[4] or 1 },
    { poly[3], poly[4], uv[3], uv[4], color[1], color[2], color[3], color[4] or 1 },
    { poly[5], poly[6], uv[5], uv[6], color[1], color[2], color[3], color[4] or 1 },
    { poly[7], poly[8], uv[7], uv[8], color[1], color[2], color[3], color[4] or 1 },
  })
  self.mesh:setTexture(texture)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.mesh)
  self.lastDrawCalls = self.lastDrawCalls + 1
  return true
end

function BuildingRenderer:prepareScene(map)
  local scene = self.SceneBuilder:build(map)
  if not scene then return nil end
  if self.prepared and self.preparedKey == scene.key then return self.prepared end

  local prepared = { scene = scene, ground = {}, buildings = {} }
  for i = 1, #scene.ground do
    local cell = scene.ground[i]
    prepared.ground[#prepared.ground + 1] = {
      x = cell.x, y = cell.y, z = cell.z,
      texture = self.AtlasSource.cellTexture(self, map, cell.x, cell.y),
    }
  end
  for i = 1, #scene.buildings do
    local b = scene.buildings[i]
    local m = b.materials
    prepared.buildings[#prepared.buildings + 1] = {
      semantic = b,
      roof = self.AtlasSource.regionTexture(self, map, m.roof.x0, m.roof.y0, m.roof.x1, m.roof.y1),
      facade = self.AtlasSource.regionTexture(self, map, m.facade.x0, m.facade.y0, m.facade.x1, m.facade.y1),
      side = self.AtlasSource.regionTexture(self, map, m.side.x0, m.side.y0, m.side.x1, m.side.y1),
      door = self.AtlasSource.cellTexture(self, map, m.door.x, m.door.y),
    }
  end
  self.preparedKey, self.prepared = scene.key, prepared
  return prepared
end

function BuildingRenderer:drawGround(proj, prepared)
  for i = 1, #prepared.ground do
    local c = prepared.ground[i]
    self:drawFace(proj, c.texture, {
      { c.x, c.y, 0 }, { c.x + 1, c.y, 0 },
      { c.x + 1, c.y + 1, 0 }, { c.x, c.y + 1, 0 },
    }, c.texture and COLORS.pixel or COLORS.ground)
    self.lastGroundCells = self.lastGroundCells + 1
  end
end

function BuildingRenderer:drawBuildingShadow(proj, profile)
  local f, a = profile.footprint, profile.architecture
  local inset = a.shadowInset or 0.04
  local poly = projectFace(proj, {
    { f.x0 + inset, f.y0 + inset, 0.004 },
    { f.x1 + 0.12, f.y0 + 0.10, 0.004 },
    { f.x1 + 0.18, f.y1 + 0.18, 0.004 },
    { f.x0 + 0.08, f.y1 + 0.14, 0.004 },
  })
  love.graphics.setColor(0, 0, 0, 0.20)
  love.graphics.polygon("fill", unpackValues(poly))
  self.lastDrawCalls = self.lastDrawCalls + 1
end

function BuildingRenderer:drawBuilding(proj, pb)
  local p = pb.semantic
  local f, a = p.footprint, p.architecture
  local x0, x1, y0, y1 = f.x0, f.x1, f.y0, f.y1
  local wallH, peak, ridge = a.wallHeight, a.roofPeak, a.ridgeY
  local over, thick = a.roofOverhang, a.roofThickness
  local xL, xR, yB, yF = x0 - over, x1 + over, y0 - over, y1 + over

  -- Right side: a real vertical face, deliberately dimmed as fixed raw-light cue.
  self:drawFace(proj, pb.side, {
    { x1, y0, 0 }, { x1, y1, 0 }, { x1, y1, wallH }, { x1, y0, wallH },
  }, COLORS.side)

  -- Front facade keeps the runtime atlas pixels at full intensity.
  self:drawFace(proj, pb.facade, {
    { x0, y1, 0 }, { x1, y1, 0 }, { x1, y1, wallH }, { x0, y1, wallH },
  }, COLORS.pixel, { 0, 1, 1, 1, 1, 0, 0, 0 })

  -- Two roof planes create a pitched roof around an authored ridge.
  self:drawFace(proj, pb.roof, {
    { xL, yB, wallH }, { xR, yB, wallH }, { xR, ridge, peak }, { xL, ridge, peak },
  }, COLORS.roofFar)
  self:drawFace(proj, pb.roof, {
    { xL, ridge, peak }, { xR, ridge, peak }, { xR, yF, wallH }, { xL, yF, wallH },
  }, COLORS.pixel, { 0, 0, 1, 0, 1, 1, 0, 1 })

  -- Roof thickness / fascia: separate vertical faces, not a flat decal.
  self:drawFace(proj, pb.roof, {
    { xL, yF, wallH - thick }, { xR, yF, wallH - thick },
    { xR, yF, wallH }, { xL, yF, wallH },
  }, COLORS.fascia, { 0, 0.75, 1, 0.75, 1, 1, 0, 1 })
  self:drawFace(proj, pb.roof, {
    { xR, yB, wallH - thick }, { xR, yF, wallH - thick },
    { xR, yF, wallH }, { xR, yB, wallH },
  }, COLORS.fascia, { 0, 0, 1, 0, 1, 0.15, 0, 0.15 })

  -- The door position is semantic and tied to Pallet's canonical (5,5) warp.
  local dx0, dx1 = p.door.x, p.door.x + p.door.width
  self:drawFace(proj, pb.door, {
    { dx0, y1 + 0.006, 0 }, { dx1, y1 + 0.006, 0 },
    { dx1, y1 + 0.006, a.doorHeight }, { dx0, y1 + 0.006, a.doorHeight },
  }, COLORS.pixel, { 0, 1, 1, 1, 1, 0, 0, 0 })

  self.lastBuildings = self.lastBuildings + 1
end

function BuildingRenderer:collectActors(state, proj)
  local out, seen = {}, {}
  for i = 1, #(state and state.entities or {}) do
    local row = actorPose(state.entities[i])
    if row then
      seen[row.actor] = true
      row.depth = proj:depth((row.basePx + 8) / CELL, (row.basePy + 12) / CELL, 0.11)
      out[#out + 1] = row
    end
  end
  if state and state.player and not seen[state.player] then
    local row = actorPose(state.player)
    if row then
      row.depth = proj:depth((row.basePx + 8) / CELL, (row.basePy + 12) / CELL, 0.11)
      out[#out + 1] = row
    end
  end
  return out
end

function BuildingRenderer:drawActor(proj, row)
  local sprite = row.sprite
  if not (sprite and type(sprite.getPoseGeometry) == "function"
          and type(sprite.resolveImage) == "function") then return false end
  local okG, g = pcall(sprite.getPoseGeometry, sprite, row.facing, row.phase, row.flip)
  local okI, image = pcall(sprite.resolveImage, sprite)
  if not okG or not okI or not g or not g.quad or not image then return false end

  local hop = row.hopping and math.max(0, row.basePy - row.py) / CELL or 0
  local wx, wy = row.basePx + 8, row.basePy + 12
  local sx, sy = proj:worldPixel(wx, wy, hop)
  local shadowX, shadowY = proj:worldPixel(wx, wy, 0)
  local s = proj.spriteScale
  love.graphics.setColor(0, 0, 0, 0.16)
  love.graphics.ellipse("fill", shadowX, shadowY + 1, 5.2 * s, 1.9 * s)
  love.graphics.setColor(1, 1, 1, 1)
  local y = sy - g.anchorY * s
  if g.mirror then
    love.graphics.draw(image, g.quad, sx + (g.width - g.anchorX) * s, y, 0, -s, s)
  else
    love.graphics.draw(image, g.quad, sx - g.anchorX * s, y, 0, s, s)
  end
  self.lastActors = self.lastActors + 1
  self.lastDrawCalls = self.lastDrawCalls + 2
  return true
end

function BuildingRenderer:drawObjects(ctx, proj, prepared)
  local commands = {}
  for i = 1, #prepared.buildings do
    local pb = prepared.buildings[i]
    local f = pb.semantic.footprint
    self:drawBuildingShadow(proj, pb.semantic)
    commands[#commands + 1] = {
      kind = "building", value = pb,
      depth = proj:depth((f.x0 + f.x1) * 0.5, f.y1 + 0.10, 0.18),
    }
  end
  local actors = self:collectActors(ctx.state, proj)
  for i = 1, #actors do
    commands[#commands + 1] = { kind = "actor", value = actors[i], depth = actors[i].depth }
  end
  table.sort(commands, function(a, b)
    if a.depth ~= b.depth then return a.depth < b.depth end
    return a.kind == "building" and b.kind == "actor"
  end)
  for i = 1, #commands do
    local c = commands[i]
    if c.kind == "building" then self:drawBuilding(proj, c.value)
    else self:drawActor(proj, c.value) end
  end
end

function BuildingRenderer:drawWorld(ctx)
  if self.level <= 0 then return nil end
  if not (ctx and ctx.state and ctx.state.map and ctx.width and ctx.height) then return nil end
  if not self:available() or not self.AtlasSource.available(ctx.state.map) then return nil end

  self:ensureResources(ctx)
  self.lastGroundCells, self.lastActors, self.lastBuildings, self.lastDrawCalls = 0, 0, 0, 0
  local prepared = self:prepareScene(ctx.state.map)
  if not prepared then return nil end
  local proj = self.Projection.new(ctx, math.max(1, math.min(3, self.level)))

  love.graphics.push("all")
  love.graphics.setCanvas(self.output)
  rgba(COLORS.sky)
  love.graphics.rectangle("fill", 0, 0, self.outputW, self.outputH)
  self:drawGround(proj, prepared)
  self:drawObjects(ctx, proj, prepared)
  if type(ctx.drawFx) == "function" then
    ctx.drawFx(function(wx, wy) return proj:worldPixel(wx, wy, 0) end, proj.spriteScale)
  end
  love.graphics.setCanvas()
  love.graphics.pop()
  return self.output
end

function BuildingRenderer:metrics()
  return {
    semanticBuilds = self.SceneBuilder.buildCount,
    materialBuilds = self.lastMaterialBuilds,
    groundCells = self.lastGroundCells,
    buildings = self.lastBuildings,
    actors = self.lastActors,
    drawCalls = self.lastDrawCalls,
  }
end

function BuildingRenderer:invalidate()
  release(self.mesh)
  release(self.output)
  self.mesh, self.output = nil, nil
  self.outputW, self.outputH = 0, 0
  self.preparedKey, self.prepared = nil, nil
  self.AtlasSource.invalidate(self)
  self.SceneBuilder:invalidate()
end

return BuildingRenderer
