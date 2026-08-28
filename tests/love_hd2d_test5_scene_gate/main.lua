local CELL = 16

local function fail(message)
  io.stderr:write("FAIL love_hd2d_test5_scene_gate: " .. tostring(message) .. "\n")
  love.event.quit(1)
end

local function module(root, rel)
  local ok, result = pcall(dofile, root .. "/packages/kanto_rework_hd2d_world/" .. rel)
  if not ok then error(result, 0) end
  return result
end

local function saveCanvas(canvas, filename)
  local data = canvas:newImageData()
  data:encode("png", filename)
  data:release()
end

local function makeSprite()
  local image = love.graphics.newCanvas(16, 20)
  love.graphics.setCanvas(image)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(0.86, 0.15, 0.10, 1)
  love.graphics.rectangle("fill", 4, 1, 8, 4)
  love.graphics.setColor(0.95, 0.72, 0.50, 1)
  love.graphics.rectangle("fill", 5, 5, 6, 5)
  love.graphics.setColor(0.14, 0.28, 0.62, 1)
  love.graphics.rectangle("fill", 3, 10, 10, 7)
  love.graphics.setColor(0.10, 0.11, 0.13, 1)
  love.graphics.rectangle("fill", 4, 17, 3, 3)
  love.graphics.rectangle("fill", 9, 17, 3, 3)
  love.graphics.setCanvas()
  image:setFilter("nearest", "nearest")
  local quad = love.graphics.newQuad(0, 0, 16, 20, 16, 20)
  return {
    getPoseGeometry = function()
      return { quad = quad, width = 16, height = 20,
               anchorX = 8, anchorY = 20, mirror = false }
    end,
    resolveImage = function() return image end,
  }
end

local function actorAt(sprite, px, py, id)
  local actor = { id = id or "RED", px = px, py = py }
  function actor:pose()
    return sprite, self.px, self.py, "down", 0, false, false
  end
  return actor
end

local function outdoorMap()
  local kinds = {}
  local function fill(x0, y0, x1, y1, kind)
    for y = y0, y1 do
      for x = x0, x1 do kinds[y * 64 + x] = kind end
    end
  end
  fill(2, 2, 4, 3, "house")
  fill(8, 2, 10, 3, "house")
  fill(8, 6, 11, 7, "lab")
  fill(1, 5, 2, 7, "tree")
  fill(11, 8, 12, 9, "tree")
  for x = 2, 11 do kinds[x] = "rock" end

  local map = {
    id = "TEST5_OUTDOOR",
    def = { tileset = "OVERWORLD" },
    widthCells = 14,
    heightCells = 11,
  }
  function map:inBounds(x, y)
    return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
  end
  function map:isWaterCell(x, y) return y >= 9 and x <= 4 end
  function map:isGrassCell(x, y)
    return y >= 5 and y <= 7 and x >= 4 and x <= 6
  end
  function map:isWarpTileCell(x, y)
    return (x == 3 and y == 4) or (x == 9 and y == 4) or (x == 9 and y == 8)
  end
  function map:warpAtCell(x, y)
    if self:isWarpTileCell(x, y) then return { index = 1 } end
    return nil
  end
  function map:isWalkableCell(x, y)
    return not self:isWaterCell(x, y) and kinds[y * 64 + x] == nil
  end
  function map:cellTile(x, y)
    local kind = kinds[y * 64 + x]
    if kind == "tree" then return 0x3D end
    if kind == "rock" then return 0x62 + (x % 3) end
    if kind == "house" then return 0x30 + ((x + y) % 3) end
    if kind == "lab" then return 0x40 + ((x + y) % 4) end
    if self:isWaterCell(x, y) then return 0x14 end
    return 0x01
  end
  function map:blockAt(bx, by)
    for cy = by * 2, by * 2 + 1 do
      for cx = bx * 2, bx * 2 + 1 do
        if kinds[cy * 64 + cx] == "tree" then return 0x0F end
      end
    end
    return 0x01
  end

  local function drawGroundCell(x, y)
    local px, py = x * CELL, y * CELL
    if map:isWaterCell(x, y) then
      love.graphics.setColor(0.20, 0.43, 0.67, 1)
      love.graphics.rectangle("fill", px, py, CELL, CELL)
      love.graphics.setColor(0.55, 0.77, 0.88, 1)
      love.graphics.rectangle("fill", px + 1, py + 4, 10, 2)
      love.graphics.rectangle("fill", px + 6, py + 11, 9, 2)
      return
    end
    local path = (x >= 5 and x <= 7) or (y == 4 and x >= 2 and x <= 11)
    if path then love.graphics.setColor(0.74, 0.69, 0.50, 1)
    else love.graphics.setColor(0.47, 0.66, 0.34, 1) end
    love.graphics.rectangle("fill", px, py, CELL, CELL)
    if map:isGrassCell(x, y) then
      love.graphics.setColor(0.22, 0.47, 0.22, 1)
      love.graphics.rectangle("fill", px + 2, py + 7, 2, 6)
      love.graphics.rectangle("fill", px + 8, py + 5, 2, 8)
      love.graphics.rectangle("fill", px + 13, py + 8, 2, 5)
    elseif not path and ((x * 7 + y * 5) % 9 == 0) then
      love.graphics.setColor(0.76, 0.83, 0.50, 1)
      love.graphics.rectangle("fill", px + 4, py + 5, 2, 2)
      love.graphics.rectangle("fill", px + 10, py + 11, 2, 2)
    end
  end

  local function drawSolidCell(x, y, kind)
    local px, py = x * CELL, y * CELL
    if kind == "tree" then
      love.graphics.setColor(0.11, 0.31, 0.15, 1)
      love.graphics.rectangle("fill", px, py, CELL, CELL)
      love.graphics.setColor(0.35, 0.59, 0.27, 1)
      love.graphics.rectangle("fill", px + 2, py + 2, 12, 8)
      love.graphics.setColor(0.51, 0.72, 0.34, 1)
      love.graphics.rectangle("fill", px + 5, py + 3, 6, 4)
    elseif kind == "rock" then
      love.graphics.setColor(0.49, 0.54, 0.54, 1)
      love.graphics.rectangle("fill", px, py, CELL, CELL)
      love.graphics.setColor(0.83, 0.84, 0.76, 1)
      love.graphics.rectangle("fill", px + 3, py + 2, 9, 5)
      love.graphics.setColor(0.33, 0.37, 0.39, 1)
      love.graphics.rectangle("fill", px + 2, py + 12, 12, 3)
    else
      local roof = y == 2 or y == 6
      if roof then
        love.graphics.setColor(kind == "lab" and 0.26 or 0.42,
                               kind == "lab" and 0.39 or 0.31,
                               kind == "lab" and 0.39 or 0.27, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.67, 0.58, 0.38, 1)
        love.graphics.rectangle("fill", px, py + 4, CELL, 3)
      else
        love.graphics.setColor(0.78, 0.78, 0.68, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.46, 0.68, 0.69, 1)
        love.graphics.rectangle("fill", px + 4, py + 6, 8, 5)
        love.graphics.setColor(0.74, 0.45, 0.12, 1)
        love.graphics.rectangle("fill", px + 6, py + 5, 4, 11)
      end
    end
  end

  map.renderer = {}
  function map.renderer:drawBorderFill(camX, camY, vw, vh)
    love.graphics.setColor(0.18, 0.24, 0.18, 1)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
  end
  function map.renderer:draw(camX, camY)
    love.graphics.push()
    love.graphics.translate(-camX, -camY)
    for y = 0, map.heightCells - 1 do
      for x = 0, map.widthCells - 1 do
        drawGroundCell(x, y)
        local kind = kinds[y * 64 + x]
        if kind then drawSolidCell(x, y, kind) end
      end
    end
    love.graphics.pop()
  end
  function map.renderer:drawMapOnly(camX, camY, vw, vh)
    self:draw(camX, camY, vw, vh)
  end
  return map
end

local function roomMap()
  local map = {
    id = "TEST5_REDS_HOUSE",
    def = { tileset = "REDSHOUSE1" },
    widthCells = 8,
    heightCells = 7,
  }
  function map:inBounds(x, y)
    return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
  end
  function map:isWaterCell() return false end
  function map:isGrassCell() return false end
  function map:isWarpTileCell(x, y) return x == 3 and y == 6 end
  function map:warpAtCell(x, y)
    if self:isWarpTileCell(x, y) then return { index = 1 } end
    return nil
  end
  function map:isWalkableCell() return true end
  function map:cellTile() return 0x01 end
  function map:blockAt() return 0x01 end

  map.renderer = {}
  function map.renderer:drawBorderFill(camX, camY, vw, vh)
    love.graphics.setColor(0.04, 0.04, 0.05, 1)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
  end
  function map.renderer:draw(camX, camY)
    love.graphics.push()
    love.graphics.translate(-camX, -camY)
    for y = 0, map.heightCells - 1 do
      for x = 0, map.widthCells - 1 do
        local px, py = x * CELL, y * CELL
        local light = ((x + y) % 2 == 0)
        love.graphics.setColor(light and 0.78 or 0.72,
                               light and 0.70 or 0.64,
                               light and 0.57 or 0.52, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
      end
    end
    love.graphics.setColor(0.48, 0.34, 0.18, 1)
    love.graphics.rectangle("fill", 3 * CELL, 2 * CELL, 2 * CELL, CELL)
    love.graphics.setColor(0.26, 0.32, 0.42, 1)
    love.graphics.rectangle("fill", 1 * CELL, 1 * CELL, 2 * CELL, CELL)
    love.graphics.setColor(0.68, 0.30, 0.23, 1)
    love.graphics.rectangle("fill", 3 * CELL, 6 * CELL, CELL, CELL)
    love.graphics.pop()
  end
  function map.renderer:drawMapOnly(camX, camY, vw, vh)
    self:draw(camX, camY, vw, vh)
  end
  return map
end

function love.load()
  love.filesystem.setIdentity("krs-hd2d-test5-scene-gate")
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local Projection = module(root, "hd2d/SceneProjection.lua")
    local Classifier = module(root, "hd2d/MaterialClassifier.lua")
    local SceneRenderer = module(root, "hd2d/SceneRenderer.lua")
    local SceneStyle = module(root, "hd2d/SceneStyle.lua")
    local LivePolish = module(root, "hd2d/LivePolish.lua")
    local DioramaPolish = module(root, "hd2d/DioramaPolish.lua")
    local Atmosphere = module(root, "hd2d/WorldAtmosphere.lua")

    local renderer = DioramaPolish.apply(
      LivePolish.apply(SceneStyle.apply(SceneRenderer.new(Projection, Classifier))))
    local atmosphere = Atmosphere.new()
    renderer:update(0, 2)
    local sprite = makeSprite()

    local outside = outdoorMap()
    local actor = actorAt(sprite, 6 * CELL, 5 * CELL, "RED")
    local outsideState = {
      map = outside, neighbors = {}, entities = { actor }, ghosts = {}, player = actor,
    }
    local outsideCtx = {
      width = 960, height = 540, vw = 160, vh = 144, scale = 4, level = 2,
      state = outsideState, cam = { x = 16, y = 8 }, bgY = 8,
      paletteFor = function()
        return { {245,240,210}, {170,185,132}, {92,110,76}, {32,39,31} }
      end,
      drawFx = function() end,
    }
    local outsideProj = Projection.new(outsideCtx, 2)
    assert((outsideProj.elevation / math.max(0.001, outsideProj.tileH)) >= 2.0,
           "TEST5 visual camera is not low enough")
    local outsideRaw = assert(renderer:drawWorld(outsideCtx), "outdoor render returned nil")
    saveCanvas(outsideRaw, "hd2d-test5-outdoor-raw.png")
    local _, py = outsideProj:worldPixel(actor.px + 8, actor.py + 12, 0)
    local outsideFinal = assert(atmosphere:present(outsideRaw, outsideCtx, 2,
                                                  py / outsideRaw:getHeight()),
                                "outdoor atmosphere returned nil")
    saveCanvas(outsideFinal, "hd2d-test5-outdoor-depth.png")
    assert((renderer.lastApronCells or 0) > 100, "outdoor apron missing")
    assert((renderer.lastVerticalizedStructures or 0) >= 3,
           "outdoor structures were not vertically staged")
    assert((renderer.lastVerticalizedVegetation or 0) >= 2,
           "outdoor vegetation was not vertically staged")
    assert((renderer.lastVerticalizedBoundaries or 0) >= 2,
           "outdoor rock boundary was not vertically staged")
    assert((renderer.lastInteriorShellPanels or 0) == 0,
           "outdoor visual received an interior shell")

    local room = roomMap()
    local roomActor = actorAt(sprite, 3 * CELL, 5 * CELL, "RED")
    local roomState = {
      map = room, neighbors = {}, entities = { roomActor }, ghosts = {}, player = roomActor,
    }
    local roomCtx = {
      width = 960, height = 540, vw = 160, vh = 144, scale = 4, level = 2,
      state = roomState, cam = { x = 0, y = 0 }, bgY = 0,
      paletteFor = outsideCtx.paletteFor,
      drawFx = function() end,
    }
    local roomProj = Projection.new(roomCtx, 2)
    local roomRaw = assert(renderer:drawWorld(roomCtx), "interior render returned nil")
    saveCanvas(roomRaw, "hd2d-test5-interior-raw.png")
    local _, rpy = roomProj:worldPixel(roomActor.px + 8, roomActor.py + 12, 0)
    local roomFinal = assert(atmosphere:present(roomRaw, roomCtx, 2,
                                               rpy / roomRaw:getHeight()),
                             "interior atmosphere returned nil")
    saveCanvas(roomFinal, "hd2d-test5-interior-depth.png")
    assert((renderer.lastInteriorShellPanels or 0) == 4,
           "interior dollhouse shell missing")
    assert((renderer.lastApronCells or 0) == 0,
           "interior visual received outdoor apron")
  end)

  if not ok then return fail(err) end
  print("PASS love_hd2d_test5_scene_gate")
  love.event.quit(0)
end
