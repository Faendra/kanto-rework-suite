local root = assert(os.getenv("KRS_ROOT"), "KRS_ROOT is required")

local RedProfile = dofile(root .. "/packages/kanto_rework_building_first/building/PalletRedHouse.lua")
local RivalProfile = dofile(root .. "/packages/kanto_rework_building_first/building/PalletRivalHouse.lua")
local OakProfile = dofile(root .. "/packages/kanto_rework_building_first/building/PalletOakLab.lua")
local Builder = dofile(root .. "/packages/kanto_rework_building_first/building/SemanticSceneBuilder.lua")
local WorldScene = dofile(root .. "/packages/kanto_rework_building_first/building/WorldScene.lua")
local WorldEnvelope = dofile(root .. "/packages/kanto_rework_building_first/building/WorldEnvelope.lua")
local Projection = dofile(root .. "/packages/kanto_rework_building_first/building/SceneProjection.lua")
local AtlasSource = dofile(root .. "/packages/kanto_rework_building_first/building/AtlasSource.lua")
local Renderer = dofile(root .. "/packages/kanto_rework_building_first/building/BuildingRenderer.lua")

local function syntheticTreePixel(id, x, y)
  local ox = (id == 71 or id == 73) and 8 or 0
  local oy = (id == 72 or id == 73) and 8 or 0
  local gx, gy = x + ox, y + oy
  local dx, dy = gx - 7.5, gy - 7.0
  local canopy = (dx * dx) / 54 + (dy * dy) / 46 <= 1
  if not canopy then return 1, 1, 1, 1 end
  local edge = (dx * dx) / 42 + (dy * dy) / 35 >= 0.70
  local v = edge and 0.25 or (((gx + gy) % 3 == 0) and 0.33 or 0.43)
  return v * 0.68, v, v * 0.60, 1
end

local function tileColor(id, x, y)
  if id == 1 then
    local c = ((x + y) % 4 == 0) and 0.68 or 0.76
    return c, c, c, 1
  elseif id == 2 then
    local c = ((x + y) % 4 == 0) and 0.38 or 0.52
    return c * 0.72, c, c * 0.70, 1
  elseif id >= 70 and id <= 73 then
    return syntheticTreePixel(id, x, y)
  elseif id >= 20 and id <= 23 then
    local stripe = ((x + y + id) % 5) < 2
    local c = stripe and 0.22 or 0.42
    return c, c, c, 1
  elseif id >= 30 and id <= 33 then
    local edge = x == 0 or y == 0
    local window = x >= 2 and x <= 5 and y >= 2 and y <= 4
    local c = edge and 0.24 or (window and 0.36 or 0.82)
    return c, c, c, 1
  elseif id == 40 then
    local door = x >= 1 and x <= 6 and y >= 1
    local c = door and 0.18 or 0.80
    return c, c, c, 1
  elseif id >= 50 and id <= 53 then
    local diamond = ((x + y + id) % 4 == 0) or ((x - y + id) % 4 == 0)
    local c = diamond and 0.74 or 0.43
    return c, c, c, 1
  elseif id >= 54 and id <= 57 then
    local stripe = (x + id) % 3 == 0
    local c = stripe and 0.30 or 0.62
    return c, c, c, 1
  elseif id >= 60 and id <= 63 then
    local mortar = (y % 4 == 0) or ((x + (math.floor(y / 4) % 2) * 3) % 6 == 0)
    local window = y <= 2 and x >= 1 and x <= 6
    local c = window and 0.30 or (mortar and 0.48 or 0.82)
    return c, c, c, 1
  elseif id == 64 then
    local frame = x == 0 or x == 7 or y == 0
    local c = frame and 0.72 or 0.20
    return c, c, c, 1
  end
  return 0.62, 0.62, 0.62, 1
end

local function makeAtlas()
  local data = love.image.newImageData(128, 48)
  for id = 0, 95 do
    local tx, ty = (id % 16) * 8, math.floor(id / 16) * 8
    for y = 0, 7 do
      for x = 0, 7 do data:setPixel(tx + x, ty + y, tileColor(id, x, y)) end
    end
  end
  local image = love.graphics.newImage(data); image:setFilter("nearest", "nearest")
  local quads = {}
  for id = 0, 95 do
    quads[id] = love.graphics.newQuad((id % 16) * 8, math.floor(id / 16) * 8, 8, 8, 128, 48)
  end
  return image, quads
end

local TREE_BLOCK = {
  70,71,70,71,
  72,73,72,73,
  70,71,70,71,
  72,73,72,73,
}
local OVERWORLD_TILESET = { blocks = { [16] = TREE_BLOCK } }

local function makeMap()
  local image, quads = makeAtlas()
  local map = {
    id = "PALLET_TOWN", def = { tileset = "OVERWORLD" }, tileset = OVERWORLD_TILESET,
    widthCells = 20, heightCells = 18, renderer = { image = image, quads = quads },
  }
  function map:warpAtCell(x, y)
    if x == 5 and y == 5 then return { def = { destMap = "REDS_HOUSE_1F", destWarp = 1 } } end
    if x == 13 and y == 5 then return { def = { destMap = "BLUES_HOUSE", destWarp = 1 } } end
    if x == 12 and y == 11 then return { def = { destMap = "OAKS_LAB", destWarp = 2 } } end
  end
  function map:tileAt(tx, ty)
    local cx, cy = math.floor(tx / 2), math.floor(ty / 2)
    local q = (ty % 2) * 2 + (tx % 2)
    local inRed = cx >= 4 and cx <= 7 and cy >= 2 and cy <= 5
    local inRival = cx >= 12 and cx <= 15 and cy >= 2 and cy <= 5
    if (inRed or inRival) and cy <= 3 then return 20 + q end
    if (inRed or inRival) and cy >= 4 then
      if (cx == 5 or cx == 13) and cy == 5 then return 40 end
      return 30 + q
    end
    local inOak = cx >= 10 and cx <= 15 and cy >= 8 and cy <= 11
    if inOak and cy <= 9 then
      if cx == 10 or cx == 15 then return 54 + q end
      return 50 + q
    end
    if inOak and cy >= 10 then
      if cx == 12 and cy == 11 then return 64 end
      return 60 + q
    end
    return 1
  end
  return map
end

local function makeRoute1(renderer)
  local map = {
    id = "ROUTE_1", def = { tileset = "OVERWORLD" }, tileset = OVERWORLD_TILESET,
    widthCells = 20, heightCells = 36, renderer = renderer,
  }
  function map:warpAtCell() end
  function map:tileAt() return 2 end
  return map
end

local function makeActor()
  local c = love.graphics.newCanvas(16, 16); c:setFilter("nearest", "nearest")
  love.graphics.push("all"); love.graphics.setCanvas(c); love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(0.18, 0.18, 0.18, 1); love.graphics.rectangle("fill", 5, 1, 6, 5)
  love.graphics.setColor(0.85, 0.85, 0.85, 1); love.graphics.rectangle("fill", 4, 6, 8, 5)
  love.graphics.setColor(0.32, 0.32, 0.32, 1)
  love.graphics.rectangle("fill", 4, 11, 3, 5); love.graphics.rectangle("fill", 9, 11, 3, 5)
  love.graphics.setCanvas(); love.graphics.pop()
  local quad = love.graphics.newQuad(0, 0, 16, 16, 16, 16)
  local sprite = {
    getPoseGeometry = function() return { quad = quad, width = 16, height = 16, anchorX = 8, anchorY = 16 } end,
    resolveImage = function() return c end,
  }
  local actor = { id = "RED", px = 10 * 16, py = 13 * 16 }
  function actor:pose() return sprite, self.px, self.py, "down", 0, false, false end
  return actor
end

local function saveCanvas(canvas, name) canvas:newImageData():encode("png", name) end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  local map, actor = makeMap(), makeActor()
  local builder = Builder.new({ RedProfile, RivalProfile, OakProfile })
  local renderer = Renderer.new(Projection, AtlasSource, builder, WorldScene, WorldEnvelope)
  renderer:update(0, 1)
  local state = { map = map, neighbors = {}, entities = { actor }, ghosts = {}, player = actor }
  local ctx = {
    width = 1280, height = 800, vw = 160, vh = 144, scale = 4,
    state = state, cam = { x = 0, y = 0 }, bgY = 0, drawFx = function() end,
  }

  actor.px, actor.py = 10 * 16, 13 * 16
  local town = assert(renderer:drawWorld(ctx)); saveCanvas(town, "building-first-raw-pallet.png")
  local townMetrics = renderer:metrics()
  actor.px, actor.py = 5 * 16, 1 * 16
  local redBehind = assert(renderer:drawWorld(ctx)); saveCanvas(redBehind, "building-first-raw-red-behind.png")
  local redMetrics = renderer:metrics()
  actor.px, actor.py = 13 * 16, 1 * 16
  local rivalBehind = assert(renderer:drawWorld(ctx)); saveCanvas(rivalBehind, "building-first-raw-rival-behind.png")
  local rivalMetrics = renderer:metrics()
  actor.px, actor.py = 12 * 16, 7 * 16
  local oakBehind = assert(renderer:drawWorld(ctx)); saveCanvas(oakBehind, "building-first-raw-oak-behind.png")
  local oakMetrics = renderer:metrics()

  for _, m in ipairs({ townMetrics, redMetrics, rivalMetrics, oakMetrics }) do
    assert(m.buildings == 3 and m.groundCells == 304 and m.worldScenes == 1)
    assert(m.groundSurfaces == 1, "Pallet ground must be one batched surface")
    assert(m.envelopeActive and m.envelopeTrees > 0, "forest envelope missing")
    assert(m.envelopeFloorRuns > 0, "local forest floor missing")
    assert(m.fillActive == false, "planar filler returned")
    assert(m.drawCalls < m.groundCells, "ground regressed to cell-scale draw calls")
  end
  assert(townMetrics.materialBuilds == redMetrics.materialBuilds
         and redMetrics.materialBuilds == rivalMetrics.materialBuilds
         and rivalMetrics.materialBuilds == oakMetrics.materialBuilds)

  local route1 = makeRoute1(map.renderer)
  state.neighbors = { { map = route1, ox = 0, oy = -36 * 16 } }
  actor.px, actor.py = 10 * 16, 1 * 16
  local connected = assert(renderer:drawWorld(ctx)); saveCanvas(connected, "building-first-raw-connected.png")
  local cm = renderer:metrics()
  assert(cm.worldScenes == 2 and cm.groundCells == 304 + 20 * 36)
  assert(cm.groundSurfaces == 2, "connected world must batch one ground surface per map")
  assert(cm.envelopeActive and cm.envelopeTrees > 0 and cm.fillActive == false)
  assert(cm.envelopeFloorRuns > 0, "connected world lost local forest floor")
  assert(cm.drawCalls < cm.groundCells, "connected ground regressed to per-cell rendering")

  print(("BUILDING_FIRST_LOVE_OK materials=%d buildings=%d ground=%d surfaces=%d scenes=%d trees=%d floorRuns=%d drawCalls=%d")
    :format(cm.materialBuilds, cm.buildings, cm.groundCells, cm.groundSurfaces,
            cm.worldScenes, cm.envelopeTrees, cm.envelopeFloorRuns, cm.drawCalls))
  love.event.quit()
end
