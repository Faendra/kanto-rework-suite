local CELL = 16

local function fail(message)
  io.stderr:write("FAIL love_hd2d_scene_gate: " .. tostring(message) .. "\n")
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

function love.load()
  love.filesystem.setIdentity("krs-hd2d-scene-gate")
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local Projection = module(root, "hd2d/SceneProjection.lua")
    local Classifier = module(root, "hd2d/MaterialClassifier.lua")
    local SceneRenderer = module(root, "hd2d/SceneRenderer.lua")
    local Atmosphere = module(root, "hd2d/WorldAtmosphere.lua")

    local renderer = SceneRenderer.new(Projection, Classifier)
    local atmosphere = Atmosphere.new()
    renderer:update(0, 2)

    local blocked = {}
    local function fill(x0, y0, x1, y1, kind)
      for y = y0, y1 do
        for x = x0, x1 do blocked[y * 64 + x] = kind end
      end
    end

    fill(2, 2, 4, 3, "house")
    fill(8, 2, 10, 3, "house")
    fill(7, 6, 11, 7, "lab")
    for y = 1, 9 do blocked[y * 64 + 0] = "tree" end
    for y = 1, 9 do blocked[y * 64 + 13] = "tree" end
    for x = 0, 13 do blocked[0 * 64 + x] = "rock" end

    local map = {
      id = "SYNTHETIC_PALLET_DIORAMA",
      def = { tileset = "OVERWORLD" },
      widthCells = 14,
      heightCells = 12,
    }

    function map:inBounds(x, y)
      return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
    end
    function map:isWaterCell(x, y)
      return y >= 10 and x <= 4
    end
    function map:isGrassCell(x, y)
      return y >= 6 and y <= 8 and x >= 2 and x <= 5
    end
    function map:isWarpTileCell(x, y)
      return (x == 3 and y == 4)
          or (x == 9 and y == 4)
          or (x == 9 and y == 8)
    end
    function map:warpAtCell(x, y)
      if self:isWarpTileCell(x, y) then return { index = 1 } end
      return nil
    end
    function map:isWalkableCell(x, y)
      if self:isWaterCell(x, y) then return false end
      return blocked[y * 64 + x] == nil
    end
    function map:cellTile(x, y)
      local kind = blocked[y * 64 + x]
      if kind == "tree" then return 0x52 end
      if kind == "rock" then return 0x60 + (x % 4) end
      if kind == "house" then return 0x30 + ((x + y) % 3) end
      if kind == "lab" then return 0x40 + ((x + y) % 4) end
      if self:isWaterCell(x, y) then return 0x14 end
      return 0x01
    end

    local function drawGroundCell(x, y)
      local px, py = x * CELL, y * CELL
      if map:isWaterCell(x, y) then
        love.graphics.setColor(0.20, 0.45, 0.66, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.46, 0.71, 0.82, 1)
        love.graphics.rectangle("fill", px + 1, py + 4, 10, 2)
        love.graphics.rectangle("fill", px + 6, py + 11, 9, 2)
        return
      end

      local path = (x >= 5 and x <= 7 and y >= 1)
                or (y == 5 and x >= 2 and x <= 11)
      if path then
        love.graphics.setColor(0.72, 0.67, 0.49, 1)
      else
        love.graphics.setColor(0.50, 0.67, 0.38, 1)
      end
      love.graphics.rectangle("fill", px, py, CELL, CELL)

      if map:isGrassCell(x, y) then
        love.graphics.setColor(0.25, 0.48, 0.24, 1)
        love.graphics.rectangle("fill", px + 2, py + 8, 2, 5)
        love.graphics.rectangle("fill", px + 8, py + 6, 2, 7)
        love.graphics.rectangle("fill", px + 13, py + 9, 2, 4)
      elseif not path and ((x * 3 + y * 5) % 7 == 0) then
        love.graphics.setColor(0.73, 0.82, 0.52, 1)
        love.graphics.rectangle("fill", px + 4, py + 5, 2, 2)
        love.graphics.rectangle("fill", px + 10, py + 11, 2, 2)
      end
    end

    local function drawFlatBlocked(x, y, kind)
      local px, py = x * CELL, y * CELL
      if kind == "tree" then
        love.graphics.setColor(0.14, 0.35, 0.17, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.34, 0.57, 0.28, 1)
        love.graphics.rectangle("fill", px + 2, py + 2, 12, 7)
      elseif kind == "rock" then
        love.graphics.setColor(0.58, 0.61, 0.58, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.82, 0.83, 0.76, 1)
        love.graphics.rectangle("fill", px + 3, py + 2, 9, 5)
      else
        love.graphics.setColor(0.65, 0.65, 0.57, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.34, 0.34, 0.30, 1)
        love.graphics.rectangle("fill", px, py, CELL, 5)
      end
    end

    map.renderer = {}
    function map.renderer:drawBorderFill(camX, camY, vw, vh)
      love.graphics.setColor(0.18, 0.23, 0.18, 1)
      love.graphics.rectangle("fill", 0, 0, vw, vh)
    end
    function map.renderer:draw(camX, camY)
      love.graphics.push()
      love.graphics.translate(-camX, -camY)
      for y = 0, map.heightCells - 1 do
        for x = 0, map.widthCells - 1 do
          drawGroundCell(x, y)
          local kind = blocked[y * 64 + x]
          if kind then drawFlatBlocked(x, y, kind) end
        end
      end
      love.graphics.pop()
    end
    function map.renderer:drawMapOnly(camX, camY, vw, vh)
      self:draw(camX, camY, vw, vh)
    end

    local actorImage = love.graphics.newCanvas(16, 20)
    love.graphics.setCanvas(actorImage)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(0.85, 0.16, 0.12, 1)
    love.graphics.rectangle("fill", 4, 1, 8, 4)
    love.graphics.setColor(0.92, 0.74, 0.55, 1)
    love.graphics.rectangle("fill", 5, 5, 6, 5)
    love.graphics.setColor(0.16, 0.31, 0.65, 1)
    love.graphics.rectangle("fill", 3, 10, 10, 7)
    love.graphics.setColor(0.13, 0.14, 0.17, 1)
    love.graphics.rectangle("fill", 4, 17, 3, 3)
    love.graphics.rectangle("fill", 9, 17, 3, 3)
    love.graphics.setCanvas()
    actorImage:setFilter("nearest", "nearest")

    local actorQuad = love.graphics.newQuad(0, 0, 16, 20, 16, 20)
    local sprite = {
      getPoseGeometry = function()
        return { quad = actorQuad, width = 16, height = 20,
                 anchorX = 8, anchorY = 20, mirror = false }
      end,
      resolveImage = function() return actorImage end,
    }
    local actor = { id = "RED", px = 6 * CELL, py = 5 * CELL }
    function actor:pose()
      return sprite, self.px, self.py, "down", 0, false, false
    end

    local state = {
      map = map,
      neighbors = {},
      entities = { actor },
      ghosts = {},
      player = actor,
    }
    local ctx = {
      width = 960, height = 540,
      vw = 160, vh = 144,
      scale = 4,
      level = 2,
      state = state,
      cam = { x = 16, y = 8 },
      bgY = 8,
      paletteFor = function()
        return {
          { 245, 240, 210 }, { 170, 185, 132 },
          { 92, 110, 76 }, { 32, 39, 31 },
        }
      end,
      drawFx = function() end,
    }

    local proj = Projection.new(ctx, 2)
    local ax, ay = proj:cell(0, 0, 0)
    local bx, by = proj:cell(1, 0, 0)
    local cx, cy = proj:cell(0, 1, 0)
    assert((bx - ax) * (cx - ax) < 0,
           "visual scene is not using a rotated isometric ground basis")
    assert(by > ay and cy > ay,
           "visual scene world axes do not recede into depth")

    local raw = assert(renderer:drawWorld(ctx), "scene renderer returned no canvas")
    saveCanvas(raw, "hd2d-scene-raw.png")

    assert(renderer.lastGroundCells >= 100,
           "scene gate emitted too little shared ground geometry")
    assert(renderer.lastTexturedGround >= 40,
           "real LÖVE texture mesh path did not texture the ground plane")
    assert(renderer.lastStructures >= 3,
           "synthetic Pallet did not reconstruct all three building volumes")
    assert(renderer.lastVegetation >= 6,
           "synthetic Pallet did not reconstruct vegetation objects")
    assert(renderer.lastActors == 1,
           "synthetic player was not rendered as an upright billboard")
    assert(renderer.lastWaterCells >= 4,
           "synthetic water contact plane missing")

    local _, playerY = proj:worldPixel(actor.px + 8, actor.py + 12, 0)
    local focusY = playerY / raw:getHeight()
    local final = assert(atmosphere:present(raw, ctx, 2, focusY),
                         "atmosphere returned no scene canvas")
    saveCanvas(final, "hd2d-scene-depth.png")
    assert(atmosphere.lastPasses == 1,
           "world-only atmosphere did not run on the diorama canvas")

    print("SCENE_RAW=" .. love.filesystem.getSaveDirectory()
          .. "/hd2d-scene-raw.png")
    print("SCENE_DEPTH=" .. love.filesystem.getSaveDirectory()
          .. "/hd2d-scene-depth.png")
    print(("SCENE_METRICS ground=%d textured=%d structures=%d vegetation=%d actors=%d water=%d commands=%d")
      :format(renderer.lastGroundCells, renderer.lastTexturedGround,
              renderer.lastStructures, renderer.lastVegetation,
              renderer.lastActors, renderer.lastWaterCells,
              renderer.lastCommands))

    actorImage:release()
    atmosphere:invalidate()
    renderer:invalidate()
  end)

  if not ok then return fail(err) end
  print("PASS love_hd2d_scene_gate")
  love.event.quit(0)
end
