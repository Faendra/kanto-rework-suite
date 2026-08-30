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
  roofSide = { 0.82, 0.82, 0.78, 1 },
  fascia = { 0.56, 0.56, 0.52, 1 },
}

local DEFAULT_ROOF_UV = { 0, 0, 1, 0, 1, 1, 0, 1 }
local DEFAULT_FASCIA_UV = { 0, 0.75, 1, 0.75, 1, 1, 0, 1 }
local VERTICAL_UV = { 0, 1, 1, 1, 1, 0, 0, 0 }

local function release(obj)
  if obj and obj.release then pcall(obj.release, obj) end
end

local function finite(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function rgba(c, alpha)
  love.graphics.setColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

local function graphicsDimensions()
  if not (love and love.graphics and type(love.graphics.getDimensions) == "function") then
    return nil, nil
  end
  local ok, w, h = pcall(love.graphics.getDimensions)
  if not ok then return nil, nil end
  return w, h
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
    out[#out + 1] = x
    out[#out + 1] = y
  end
  return out
end

local function regionTexture(source, host, map, region)
  if not region then return nil end
  return source.regionTexture(host, map, region.x0, region.y0, region.x1, region.y1)
end

function BuildingRenderer.new(Projection, AtlasSource, SceneBuilder, WorldScene, WorldEnvelope)
  return setmetatable({
    Projection = assert(Projection),
    AtlasSource = assert(AtlasSource),
    SceneBuilder = assert(SceneBuilder),
    WorldScene = assert(WorldScene),
    WorldEnvelope = assert(WorldEnvelope),
    level = 0,
    mesh = nil,
    output = nil,
    treeKeyShader = nil,
    outputW = 0,
    outputH = 0,
    preparedKey = nil,
    prepared = nil,
    atlasCellCache = {},
    atlasRegionCache = {},
    atlasBlockCache = {},
    resourceIdentityReady = false,
    resourceMap = nil,
    resourceMapId = nil,
    resourceRenderer = nil,
    resourceImage = nil,
    resourceQuads = nil,
    resourceWorldKey = nil,
    resourceCtxW = nil,
    resourceCtxH = nil,
    resourceGraphicsW = nil,
    resourceGraphicsH = nil,
    resourceResets = 0,
    lastMaterialBuilds = 0,
    lastGroundCells = 0,
    lastActors = 0,
    lastBuildings = 0,
    lastWorldScenes = 0,
    lastEnvelopeTrees = 0,
    lastEnvelopeActive = false,
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

-- Atlas-derived materials are GPU canvases owned by this renderer. A new
-- game/save session can replace map.renderer (or the runtime atlas) while the
-- render-pipeline Lua object survives. Connected neighbor maps are part of
-- that generation too: changing a neighbor set must not leave stale atlas
-- canvases at world seams.
function BuildingRenderer:dropTransientResources()
  release(self.mesh)
  release(self.output)
  release(self.treeKeyShader)
  self.mesh, self.output, self.treeKeyShader = nil, nil, nil
  self.outputW, self.outputH = 0, 0
  self.preparedKey, self.prepared = nil, nil
  self.AtlasSource.invalidate(self)
end

function BuildingRenderer:syncResourceIdentity(ctx, state)
  local map = state and state.map
  local r = map and map.renderer
  local ctxW = math.max(1, math.floor(tonumber(ctx and ctx.width) or 1))
  local ctxH = math.max(1, math.floor(tonumber(ctx and ctx.height) or 1))
  local graphicsW, graphicsH = graphicsDimensions()
  local worldKey = self.WorldScene.identity(state)

  local changed = self.resourceIdentityReady and (
       self.resourceMap ~= map
    or self.resourceMapId ~= (map and map.id)
    or self.resourceRenderer ~= r
    or self.resourceImage ~= (r and r.image)
    or self.resourceQuads ~= (r and r.quads)
    or self.resourceWorldKey ~= worldKey
    or self.resourceCtxW ~= ctxW
    or self.resourceCtxH ~= ctxH
    or self.resourceGraphicsW ~= graphicsW
    or self.resourceGraphicsH ~= graphicsH)

  if changed then
    self:dropTransientResources()
    self.resourceResets = self.resourceResets + 1
  end

  self.resourceIdentityReady = true
  self.resourceMap = map
  self.resourceMapId = map and map.id or nil
  self.resourceRenderer = r
  self.resourceImage = r and r.image or nil
  self.resourceQuads = r and r.quads or nil
  self.resourceWorldKey = worldKey
  self.resourceCtxW, self.resourceCtxH = ctxW, ctxH
  self.resourceGraphicsW, self.resourceGraphicsH = graphicsW, graphicsH
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
  if not self.treeKeyShader and type(love.graphics.newShader) == "function" then
    local ok, shader = pcall(love.graphics.newShader, [[
      vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 p = Texel(tex, tc) * color;
        if (p.r > 0.83 && p.g > 0.83 && p.b > 0.83) p.a = 0.0;
        return p;
      }
    ]])
    if ok then self.treeKeyShader = shader end
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

  uv = uv or DEFAULT_ROOF_UV
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

-- Build one connected render scene from the primary map plus the exact maps
-- Gen1Recomp already exposes in state.neighbors. No geometry is inferred at
-- seams: each neighbor keeps its own vanilla cells and receives only its
-- engine-provided world offset. The exterior is now an object envelope, not
-- a projected texture plane.
function BuildingRenderer:prepareScene(state)
  local worldKey = self.WorldScene.identity(state)
  if self.prepared and self.preparedKey == worldKey then return self.prepared end

  local worldScenes = self.WorldScene.collect(state)
  local prepared = {
    worldKey = worldKey,
    worldScenes = worldScenes,
    ground = {},
    buildings = {},
  }

  for _, world in ipairs(worldScenes) do
    local scene = self.SceneBuilder:build(world.map)
    if scene then
      for i = 1, #scene.ground do
        local cell = scene.ground[i]
        prepared.ground[#prepared.ground + 1] = {
          x = cell.x + world.cx,
          y = cell.y + world.cy,
          z = cell.z,
          texture = self.AtlasSource.cellTexture(self, world.map, cell.x, cell.y),
        }
      end
      for i = 1, #scene.buildings do
        local b = scene.buildings[i]
        local m = b.materials
        prepared.buildings[#prepared.buildings + 1] = {
          semantic = b,
          ox = world.cx,
          oy = world.cy,
          roof = regionTexture(self.AtlasSource, self, world.map, m.roof),
          roofLeft = regionTexture(self.AtlasSource, self, world.map, m.roofLeft),
          roofRight = regionTexture(self.AtlasSource, self, world.map, m.roofRight),
          facade = regionTexture(self.AtlasSource, self, world.map, m.facade),
          side = regionTexture(self.AtlasSource, self, world.map, m.side),
          door = m.door and self.AtlasSource.cellTexture(self, world.map, m.door.x, m.door.y) or nil,
        }
      end
    end
  end

  prepared.envelope = self.WorldEnvelope.build(state, worldScenes)
  if prepared.envelope and prepared.envelope.kind == "forest" then
    prepared.envelopeTexture = self.AtlasSource.treeWallTexture(self, state and state.map)
  end

  self.preparedKey, self.prepared = worldKey, prepared
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

function BuildingRenderer:drawBuildingShadow(proj, pb)
  local profile = pb.semantic
  local ox, oy = pb.ox or 0, pb.oy or 0
  local f, a = profile.footprint, profile.architecture
  local inset = a.shadowInset or 0.04
  local poly = projectFace(proj, {
    { f.x0 + ox + inset, f.y0 + oy + inset, 0.004 },
    { f.x1 + ox + 0.12, f.y0 + oy + 0.10, 0.004 },
    { f.x1 + ox + 0.18, f.y1 + oy + 0.18, 0.004 },
    { f.x0 + ox + 0.08, f.y1 + oy + 0.14, 0.004 },
  })
  love.graphics.setColor(0, 0, 0, 0.20)
  love.graphics.polygon("fill", unpackValues(poly))
  self.lastDrawCalls = self.lastDrawCalls + 1
end

function BuildingRenderer:drawGableRoof(proj, pb, xL, xR, yB, yF, wallH, peak, ridge, thick, a)
  local roofUV = a.roofUV or DEFAULT_ROOF_UV
  local fasciaUV = a.fasciaUV or DEFAULT_FASCIA_UV

  self:drawFace(proj, pb.roof, {
    { xL, yB, wallH }, { xR, yB, wallH }, { xR, ridge, peak }, { xL, ridge, peak },
  }, COLORS.roofFar, roofUV)
  self:drawFace(proj, pb.roof, {
    { xL, ridge, peak }, { xR, ridge, peak }, { xR, yF, wallH }, { xL, yF, wallH },
  }, COLORS.pixel, roofUV)

  self:drawFace(proj, pb.roof, {
    { xL, yF, wallH - thick }, { xR, yF, wallH - thick },
    { xR, yF, wallH }, { xL, yF, wallH },
  }, COLORS.fascia, fasciaUV)
  self:drawFace(proj, pb.roof, {
    { xR, yB, wallH - thick }, { xR, yF, wallH - thick },
    { xR, yF, wallH }, { xR, yB, wallH },
  }, COLORS.fascia, { 0, 0, 1, 0, 1, 0.15, 0, 0.15 })
end

function BuildingRenderer:drawHipRoof(proj, pb, xL, xR, yB, yF, wallH, peak, ridge, thick, a)
  local inset = a.ridgeInsetX or 1.0
  local ridgeL, ridgeR = xL + inset, xR - inset
  local roofUV = a.roofUV or DEFAULT_ROOF_UV
  local fasciaUV = a.fasciaUV or DEFAULT_FASCIA_UV
  local sideUV = a.roofSideUV or DEFAULT_ROOF_UV

  self:drawFace(proj, pb.roof, {
    { xL, yB, wallH }, { xR, yB, wallH },
    { ridgeR, ridge, peak }, { ridgeL, ridge, peak },
  }, COLORS.roofFar, roofUV)
  self:drawFace(proj, pb.roof, {
    { ridgeL, ridge, peak }, { ridgeR, ridge, peak },
    { xR, yF, wallH }, { xL, yF, wallH },
  }, COLORS.pixel, roofUV)

  self:drawFace(proj, pb.roofLeft or pb.roof, {
    { xL, yB, wallH }, { ridgeL, ridge, peak },
    { xL, yF, wallH }, { xL, yF, wallH },
  }, COLORS.roofSide, sideUV)
  self:drawFace(proj, pb.roofRight or pb.roof, {
    { xR, yF, wallH }, { ridgeR, ridge, peak },
    { xR, yB, wallH }, { xR, yB, wallH },
  }, COLORS.pixel, sideUV)

  self:drawFace(proj, pb.roof, {
    { xL, yF, wallH - thick }, { xR, yF, wallH - thick },
    { xR, yF, wallH }, { xL, yF, wallH },
  }, COLORS.fascia, fasciaUV)
  self:drawFace(proj, pb.roofRight or pb.roof, {
    { xR, yB, wallH - thick }, { xR, yF, wallH - thick },
    { xR, yF, wallH }, { xR, yB, wallH },
  }, COLORS.fascia, { 0, 0, 1, 0, 1, 0.20, 0, 0.20 })
end

function BuildingRenderer:drawBuilding(proj, pb)
  local p = pb.semantic
  local ox, oy = pb.ox or 0, pb.oy or 0
  local f, a = p.footprint, p.architecture
  local x0, x1 = f.x0 + ox, f.x1 + ox
  local y0, y1 = f.y0 + oy, f.y1 + oy
  local wallH, peak, ridge = a.wallHeight, a.roofPeak, a.ridgeY + oy
  local over, thick = a.roofOverhang, a.roofThickness
  local xL, xR, yB, yF = x0 - over, x1 + over, y0 - over, y1 + over

  self:drawFace(proj, pb.side, {
    { x1, y0, 0 }, { x1, y1, 0 }, { x1, y1, wallH }, { x1, y0, wallH },
  }, COLORS.side)

  self:drawFace(proj, pb.facade, {
    { x0, y1, 0 }, { x1, y1, 0 }, { x1, y1, wallH }, { x0, y1, wallH },
  }, COLORS.pixel, VERTICAL_UV)

  local roofStyle = a.roofStyle or "gable"
  if roofStyle == "hip" then
    self:drawHipRoof(proj, pb, xL, xR, yB, yF, wallH, peak, ridge, thick, a)
  else
    self:drawGableRoof(proj, pb, xL, xR, yB, yF, wallH, peak, ridge, thick, a)
  end

  local dx0 = p.door.x + ox
  local dx1 = p.door.x + p.door.width + ox
  self:drawFace(proj, pb.door, {
    { dx0, y1 + 0.006, 0 }, { dx1, y1 + 0.006, 0 },
    { dx1, y1 + 0.006, a.doorHeight }, { dx0, y1 + 0.006, a.doorHeight },
  }, COLORS.pixel, VERTICAL_UV)

  self.lastBuildings = self.lastBuildings + 1
end

-- Tree canopies follow the same HD-2D rule as actors: a semantic world
-- position plus a screen-upright sprite, scaled by local perspective. The
-- source pixels define appearance only; they never define world geometry.
function BuildingRenderer:drawTreeCluster(proj, texture, tree)
  if not (texture and tree) then return false end
  local x, y, z = tree.x, tree.y, tree.z or 0
  local _, _, cameraDepth = proj:cameraCoordinates(x, y, z)
  if cameraDepth <= proj.near then return false end

  local sx, sy = proj:cell(x, y, z)
  local bx, by = proj:cell(x + 1, y, z)
  local cx, cy = proj:cell(x, y + 1, z)
  local basisX = math.sqrt((bx - sx) * (bx - sx) + (by - sy) * (by - sy))
  local basisY = math.sqrt((cx - sx) * (cx - sx) + (cy - sy) * (cy - sy))
  local localCellPx = (basisX + basisY) * 0.5
  if not finite(localCellPx) or localCellPx <= 0 then return false end

  local tw, th = CELL, CELL
  if type(texture.getDimensions) == "function" then
    local ok, w, h = pcall(texture.getDimensions, texture)
    if ok and finite(w) and finite(h) and w > 0 and h > 0 then tw, th = w, h end
  end
  local scale = localCellPx * (tree.width or 1.68) / tw
  local drawW, drawH = tw * scale, th * scale
  local margin = math.max(drawW, drawH) * 1.25
  if sx < -margin or sx > self.outputW + margin
     or sy < -margin or sy > self.outputH + margin then return false end

  if self.treeKeyShader and type(love.graphics.setShader) == "function" then
    love.graphics.setShader(self.treeKeyShader)
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(texture, sx, sy, 0, scale, scale, tw * 0.5, th)
  if type(love.graphics.setShader) == "function" then love.graphics.setShader() end

  self.lastEnvelopeTrees = self.lastEnvelopeTrees + 1
  self.lastDrawCalls = self.lastDrawCalls + 1
  return true
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

  local envelope = prepared.envelope
  if envelope and envelope.kind == "forest" and prepared.envelopeTexture then
    self.lastEnvelopeActive = true
    for i = 1, #envelope.trees do
      local tree = envelope.trees[i]
      commands[#commands + 1] = {
        kind = "tree", value = tree,
        depth = proj:depth(tree.x, tree.y + 0.04, 0.05),
      }
    end
  end

  for i = 1, #prepared.buildings do
    local pb = prepared.buildings[i]
    local f = pb.semantic.footprint
    local ox, oy = pb.ox or 0, pb.oy or 0
    self:drawBuildingShadow(proj, pb)
    commands[#commands + 1] = {
      kind = "building", value = pb,
      depth = proj:depth((f.x0 + f.x1) * 0.5 + ox, f.y1 + oy + 0.10, 0.18),
    }
  end

  local actors = self:collectActors(ctx.state, proj)
  for i = 1, #actors do
    commands[#commands + 1] = { kind = "actor", value = actors[i], depth = actors[i].depth }
  end

  local rank = { tree = 1, building = 2, actor = 3 }
  table.sort(commands, function(a, b)
    if a.depth ~= b.depth then return a.depth < b.depth end
    return (rank[a.kind] or 9) < (rank[b.kind] or 9)
  end)

  for i = 1, #commands do
    local c = commands[i]
    if c.kind == "building" then
      self:drawBuilding(proj, c.value)
    elseif c.kind == "tree" then
      self:drawTreeCluster(proj, prepared.envelopeTexture, c.value)
    else
      self:drawActor(proj, c.value)
    end
  end
end

function BuildingRenderer:drawWorld(ctx)
  if self.level <= 0 then return nil end
  if not (ctx and ctx.state and ctx.state.map and ctx.width and ctx.height) then return nil end
  if not self:available() or not self.AtlasSource.available(ctx.state.map) then return nil end

  self:syncResourceIdentity(ctx, ctx.state)
  self:ensureResources(ctx)
  self.lastGroundCells, self.lastActors, self.lastBuildings, self.lastDrawCalls = 0, 0, 0, 0
  self.lastWorldScenes, self.lastEnvelopeTrees, self.lastEnvelopeActive = 0, 0, false
  local prepared = self:prepareScene(ctx.state)
  if not prepared then return nil end
  self.lastWorldScenes = #prepared.worldScenes
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
    resourceResets = self.resourceResets,
    groundCells = self.lastGroundCells,
    buildings = self.lastBuildings,
    actors = self.lastActors,
    worldScenes = self.lastWorldScenes,
    envelopeActive = self.lastEnvelopeActive,
    envelopeTrees = self.lastEnvelopeTrees,
    fillActive = false,
    drawCalls = self.lastDrawCalls,
  }
end

function BuildingRenderer:invalidate()
  self:dropTransientResources()
  self.resourceIdentityReady = false
  self.resourceMap = nil
  self.resourceMapId = nil
  self.resourceRenderer = nil
  self.resourceImage = nil
  self.resourceQuads = nil
  self.resourceWorldKey = nil
  self.resourceCtxW, self.resourceCtxH = nil, nil
  self.resourceGraphicsW, self.resourceGraphicsH = nil, nil
  self.SceneBuilder:invalidate()
end

return BuildingRenderer
