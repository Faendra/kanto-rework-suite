local root = assert(os.getenv("KRS_ROOT"), "KRS_ROOT is required")

local Profile = dofile(root .. "/packages/kanto_rework_building_first/building/PalletRedHouse.lua")
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
    return nil
  end
  function map:tileAt(tx, ty)
    local cx, cy = math.floor(tx / 2), math.floor(ty / 2)
    local q = (ty % 2) * 2 + (tx % 2)
    if cx >= 4 and cx <= 7 and cy >= 2 and cy <= 3 then return 20 + q end
    if cx >= 4 and cx <= 7 and cy >= 4 and cy <= 5 then
      if cx == 5 and cy == 5 then return 40 end
      return 30 + q
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
  local actor = { id = "RED", px = 5 * 16, py = 7 * 16 }
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
  local builder = Builder.new(Profile)
  local renderer = Renderer.new(Projection, AtlasSource, builder)
  renderer:update(0, 1)
  local state = { map = map, neighbors = {}, entities = { actor }, ghosts = {}, player = actor }
  local ctx = {
    width = 960, height = 720, vw = 160, vh = 144, scale = 4,
    state = state, cam = { x = 0, y = 0 }, bgY = 0,
    drawFx = function() end,
  }

  actor.py = 7 * 16
  local front = assert(renderer:drawWorld(ctx), "front raw render missing")
  saveCanvas(front, "building-first-raw-front.png")
  local frontMetrics = renderer:metrics()

  actor.py = 1 * 16
  local behind = assert(renderer:drawWorld(ctx), "behind raw render missing")
  saveCanvas(behind, "building-first-raw-behind.png")
  local behindMetrics = renderer:metrics()

  assert(frontMetrics.buildings == 1 and behindMetrics.buildings == 1, "building count changed")
  assert(frontMetrics.semanticBuilds == 1 and behindMetrics.semanticBuilds == 1, "scene cache regressed")
  assert(frontMetrics.materialBuilds == behindMetrics.materialBuilds, "material cache regressed")
  print(("BUILDING_FIRST_LOVE_OK semantic=%d materials=%d ground=%d drawCalls=%d")
    :format(behindMetrics.semanticBuilds, behindMetrics.materialBuilds,
            behindMetrics.groundCells, behindMetrics.drawCalls))
  love.event.quit()
end
