local root = assert(os.getenv("KRS_ROOT"), "KRS_ROOT is required")

local RedProfile = dofile(root .. "/packages/kanto_rework_building_first/building/PalletRedHouse.lua")
local RivalProfile = dofile(root .. "/packages/kanto_rework_building_first/building/PalletRivalHouse.lua")
local OakProfile = dofile(root .. "/packages/kanto_rework_building_first/building/PalletOakLab.lua")
local Builder = dofile(root .. "/packages/kanto_rework_building_first/building/SemanticSceneBuilder.lua")
local Projection = dofile(root .. "/packages/kanto_rework_building_first/building/SceneProjection.lua")
local AtlasSource = dofile(root .. "/packages/kanto_rework_building_first/building/AtlasSource.lua")
local Renderer = dofile(root .. "/packages/kanto_rework_building_first/building/BuildingRenderer.lua")

local function tileColor(id, x, y)
  if id == 1 then
    local c = ((x + y) % 4 == 0) and 0.68 or 0.76
    return c, c, c, 1
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
      for x = 0, 7 do
        data:setPixel(tx + x, ty + y, tileColor(id, x, y))
      end
    end
  end
  local image = love.graphics.newImage(data)
  image:setFilter("nearest", "nearest")
  local quads = {}
  for id = 0, 95 do
    quads[id] = love.graphics.newQuad((id % 16) * 8, math.floor(id / 16) * 8,
                                      8, 8, 128, 48)
  end
  return image, quads
end

local function makeMap()
  local image, quads = makeAtlas()
  local map = {
    id = "PALLET_TOWN", def = { tileset = "OVERWORLD" },
    widthCells = 20, heightCells = 18,
    renderer = { image = image, quads = quads },
  }
  function map:warpAtCell(x, y)
    if x == 5 and y == 5 then return { def = { destMap = "REDS_HOUSE_1F", destWarp = 1 } } end
    if x == 13 and y == 5 then return { def = { destMap = "BLUES_HOUSE", destWarp = 1 } } end
    if x == 12 and y == 11 then return { def = { destMap = "OAKS_LAB", destWarp = 2 } } end
    return nil
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

local function makeActor()
  local c = love.graphics.newCanvas(16, 16)
  c:setFilter("nearest", "nearest")
  love.graphics.push("all")
  love.graphics.setCanvas(c)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(0.18, 0.18, 0.18, 1)
  love.graphics.rectangle("fill", 5, 1, 6, 5)
  love.graphics.setColor(0.85, 0.85, 0.85, 1)
  love.graphics.rectangle("fill", 4, 6, 8, 5)
  love.graphics.setColor(0.32, 0.32, 0.32, 1)
  love.graphics.rectangle("fill", 4, 11, 3, 5)
  love.graphics.rectangle("fill", 9, 11, 3, 5)
  love.graphics.setCanvas()
  love.graphics.pop()
  local quad = love.graphics.newQuad(0, 0, 16, 16, 16, 16)
  local sprite = {
    getPoseGeometry = function()
      return { quad = quad, width = 16, height = 16, anchorX = 8, anchorY = 16 }
    end,
    resolveImage = function() return c end,
  }
  local actor = { id = "RED", px = 10 * 16, py = 13 * 16 }
  function actor:pose() return sprite, self.px, self.py, "down", 0, false, false end
  return actor
end

local function saveCanvas(canvas, name)
  local data = canvas:newImageData()
  data:encode("png", name)
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  local map = makeMap()
  local actor = makeActor()
  local builder = Builder.new({ RedProfile, RivalProfile, OakProfile })
  local renderer = Renderer.new(Projection, AtlasSource, builder)
  renderer:update(0, 1)
  local state = { map = map, neighbors = {}, entities = { actor }, ghosts = {}, player = actor }
  local ctx = {
    width = 1280, height = 800, vw = 160, vh = 144, scale = 4,
    state = state, cam = { x = 0, y = 0 }, bgY = 0,
    drawFx = function() end,
  }

  actor.px, actor.py = 10 * 16, 13 * 16
  local town = assert(renderer:drawWorld(ctx), "Pallet raw render missing")
  saveCanvas(town, "building-first-raw-pallet.png")
  local townMetrics = renderer:metrics()

  actor.px, actor.py = 5 * 16, 1 * 16
  local redBehind = assert(renderer:drawWorld(ctx), "Red-house behind render missing")
  saveCanvas(redBehind, "building-first-raw-red-behind.png")
  local redMetrics = renderer:metrics()

  actor.px, actor.py = 13 * 16, 1 * 16
  local rivalBehind = assert(renderer:drawWorld(ctx), "rival-house behind render missing")
  saveCanvas(rivalBehind, "building-first-raw-rival-behind.png")
  local rivalMetrics = renderer:metrics()

  actor.px, actor.py = 12 * 16, 7 * 16
  local oakBehind = assert(renderer:drawWorld(ctx), "Oak-lab behind render missing")
  saveCanvas(oakBehind, "building-first-raw-oak-behind.png")
  local oakMetrics = renderer:metrics()

  for _, metrics in ipairs({ townMetrics, redMetrics, rivalMetrics, oakMetrics }) do
    assert(metrics.buildings == 3, "building count changed")
    assert(metrics.semanticBuilds == 1, "scene cache regressed")
    assert(metrics.groundCells == 304, "semantic footprint mask regressed")
  end
  assert(townMetrics.materialBuilds == redMetrics.materialBuilds
         and redMetrics.materialBuilds == rivalMetrics.materialBuilds
         and rivalMetrics.materialBuilds == oakMetrics.materialBuilds,
         "material cache regressed")
  print(("BUILDING_FIRST_LOVE_OK semantic=%d materials=%d buildings=%d ground=%d drawCalls=%d")
    :format(oakMetrics.semanticBuilds, oakMetrics.materialBuilds,
            oakMetrics.buildings, oakMetrics.groundCells, oakMetrics.drawCalls))
  love.event.quit()
end
