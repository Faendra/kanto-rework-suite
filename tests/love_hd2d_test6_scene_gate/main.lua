local CELL = 16

local function fail(message)
  io.stderr:write("FAIL love_hd2d_test6_scene_gate: " .. tostring(message) .. "\n")
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
  love.filesystem.setIdentity("krs-hd2d-test6-scene-gate")
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local Projection = module(root, "hd2d/SceneProjection.lua")
    local Classifier = module(root, "hd2d/MaterialClassifier.lua")
    local SceneRenderer = module(root, "hd2d/SceneRenderer.lua")
    local SceneStyle = module(root, "hd2d/SceneStyle.lua")
    local LivePolish = module(root, "hd2d/LivePolish.lua")
    local DioramaPolish = module(root, "hd2d/DioramaPolish.lua")
    local NaturalForms = module(root, "hd2d/NaturalForms.lua")
    local Continuity = module(root, "hd2d/SceneContinuity.lua")
    local Atmosphere = module(root, "hd2d/WorldAtmosphere.lua")

    local renderer = Continuity.apply(
      NaturalForms.apply(
        DioramaPolish.apply(
          LivePolish.apply(
            SceneStyle.apply(SceneRenderer.new(Projection, Classifier))))))
    renderer:update(0, 2)
    local atmosphere = Atmosphere.new()

    local blocked = {}
    local function set(x, y, kind) blocked[y * 64 + x] = kind end
    for x = 0, 11 do set(x, 0, "rock") end
    for y = 1, 8 do set(0, y, "rock") end
    for x = 2, 5 do set(x, 3, "tree") end
    for y = 5, 6 do for x = 7, 9 do set(x, y, "house") end end

    local map = {
      id = "SYNTHETIC_ROUTE_TEST6",
      def = { tileset = "OVERWORLD" },
      widthCells = 12,
      heightCells = 10,
    }
    function map:inBounds(x, y)
      return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
    end
    function map:isWaterCell() return false end
    function map:isGrassCell(x, y)
      return y >= 6 and y <= 8 and x >= 2 and x <= 4
    end
    function map:isWarpTileCell(x, y) return x == 8 and y == 7 end
    function map:warpAtCell(x, y)
      if self:isWarpTileCell(x, y) then return { index = 1 } end
      return nil
    end
    function map:isWalkableCell(x, y)
      return blocked[y * 64 + x] == nil
    end
    function map:cellTile(x, y)
      local kind = blocked[y * 64 + x]
      if kind == "tree" then return 0x45 end
      if kind == "rock" then return 0x60 + ((x * 3 + y) % 5) end
      if kind == "house" then return 0x30 + ((x + y) % 3) end
      return 0x01
    end
    function map:blockAt(bx, by)
      if by == 1 and bx >= 1 and bx <= 2 then return 0x0B end
      return 0x01
    end

    local function drawGround(x, y)
      local px, py = x * CELL, y * CELL
      local path = (x >= 5 and x <= 6) or y == 4
      if path then
        love.graphics.setColor(0.78, 0.78, 0.66, 1)
      else
        love.graphics.setColor(0.52, 0.76, 0.31, 1)
      end
      love.graphics.rectangle("fill", px, py, CELL, CELL)
      if map:isGrassCell(x, y) then
        love.graphics.setColor(0.20, 0.48, 0.18, 1)
        love.graphics.rectangle("fill", px + 2, py + 7, 2, 6)
        love.graphics.rectangle("fill", px + 8, py + 5, 2, 8)
        love.graphics.rectangle("fill", px + 13, py + 8, 2, 5)
      end
    end

    local function drawBlocked(x, y, kind)
      local px, py = x * CELL, y * CELL
      if kind == "rock" then
        love.graphics.setColor(0.48, 0.52, 0.50, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.84, 0.86, 0.80, 1)
        love.graphics.rectangle("fill", px + 3, py + 2, 9, 6)
        love.graphics.setColor(0.26, 0.30, 0.30, 1)
        love.graphics.rectangle("fill", px + 2, py + 11, 12, 3)
      elseif kind == "tree" then
        love.graphics.setColor(0.10, 0.34, 0.13, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.36, 0.72, 0.25, 1)
        love.graphics.rectangle("fill", px + 2, py + 2, 12, 9)
        love.graphics.setColor(0.68, 0.86, 0.36, 1)
        love.graphics.rectangle("fill", px + 5, py + 2, 6, 4)
      elseif kind == "house" then
        love.graphics.setColor(0.78, 0.81, 0.73, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.31, 0.42, 0.43, 1)
        love.graphics.rectangle("fill", px, py, CELL, 5)
        love.graphics.setColor(0.78, 0.47, 0.12, 1)
        love.graphics.rectangle("fill", px + 5, py + 5, 6, 11)
      end
    end

    map.renderer = {}
    function map.renderer:drawBorderFill(camX, camY, vw, vh)
      love.graphics.setColor(0.20, 0.32, 0.18, 1)
      love.graphics.rectangle("fill", 0, 0, vw, vh)
    end
    function map.renderer:draw(camX, camY)
      love.graphics.push()
      love.graphics.translate(-camX, -camY)
      for y = 0, map.heightCells - 1 do
        for x = 0, map.widthCells - 1 do
          drawGround(x, y)
          local kind = blocked[y * 64 + x]
          if kind then drawBlocked(x, y, kind) end
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
    love.graphics.setColor(0.82, 0.15, 0.10, 1)
    love.graphics.rectangle("fill", 4, 1, 8, 4)
    love.graphics.setColor(0.92, 0.73, 0.53, 1)
    love.graphics.rectangle("fill", 5, 5, 6, 5)
    love.graphics.setColor(0.16, 0.30, 0.66, 1)
    love.graphics.rectangle("fill", 3, 10, 10, 7)
    love.graphics.setColor(0.12, 0.13, 0.15, 1)
    love.graphics.rectangle("fill", 4, 17, 3, 3)
    love.graphics.rectangle("fill", 9, 17, 3, 3)
    love.graphics.setCanvas()
    actorImage:setFilter("nearest", "nearest")
    local quad = love.graphics.newQuad(0, 0, 16, 20, 16, 20)
    local sprite = {
      getPoseGeometry = function()
        return { quad = quad, width = 16, height = 20,
                 anchorX = 8, anchorY = 20, mirror = false }
      end,
      resolveImage = function() return actorImage end,
    }
    local function makeActor(id, px, py)
      local actor = { id = id, px = px, py = py }
      function actor:pose()
        return sprite, self.px, self.py, "down", 0, false, false
      end
      return actor
    end

    local player = makeActor("RED", 6 * CELL, 5 * CELL)
    local npc = makeActor("NPC", 5 * CELL, 2 * CELL)
    local remote = makeActor("REMOTE", 30 * CELL, 30 * CELL)
    local state = {
      map = map,
      neighbors = {},
      entities = { player, npc },
      ghosts = { { npc = remote, map = map, ox = 0, oy = 0 } },
      player = player,
    }
    local ctx = {
      width = 960,
      height = 540,
      vw = 160,
      vh = 144,
      level = 2,
      scale = 4,
      state = state,
      cam = { x = 16, y = 8 },
      bgY = 8,
      paletteFor = function()
        return {
          { 245, 240, 210 }, { 170, 190, 132 },
          { 92, 110, 76 }, { 32, 39, 31 },
        }
      end,
      drawFx = function() end,
    }

    local raw = assert(renderer:drawWorld(ctx), "TEST6 renderer returned no canvas")
    saveCanvas(raw, "hd2d-test6-route-raw.png")
    assert((renderer.lastNaturalVegetationCards or 0) >= 2,
           "TEST6 route did not render source-textured vegetation cards")
    assert((renderer.lastNaturalBoundaryCards or 0) >= 6,
           "TEST6 route did not replace long boundary wall with natural cards")
    assert((renderer.lastNaturalCardFallbacks or 0) == 0,
           "TEST6 route fell back to old natural geometry")
    assert((renderer.lastCulledUnsupportedActors or 0) == 1,
           "TEST6 route did not cull unsupported remote actor")
    assert(renderer.lastActors == 2,
           "TEST6 route should render only player and supported NPC")

    local proj = Projection.new(ctx, 2)
    local _, playerY = proj:worldPixel(player.px + 8, player.py + 12, 0)
    local final = assert(atmosphere:present(raw, ctx, 2, playerY / raw:getHeight()),
                         "TEST6 atmosphere returned no canvas")
    saveCanvas(final, "hd2d-test6-route-depth.png")
  end)

  if not ok then return fail(err) end
  print("PASS love_hd2d_test6_scene_gate")
  love.event.quit(0)
end
