local CELL = 16

local function fail(message)
  io.stderr:write("FAIL love_hd2d_visual_gate: " .. tostring(message) .. "\n")
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
  love.filesystem.setIdentity("krs-hd2d-visual-gate")
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local Projection = module(root, "hd2d/Projection.lua")
    local Classifier = module(root, "hd2d/MaterialClassifier.lua")
    local Relief = module(root, "hd2d/Relief.lua")
    local WaterSurface = module(root, "hd2d/WaterSurface.lua")
    local Occlusion = module(root, "hd2d/Occlusion.lua")
    local DepthComposer = module(root, "hd2d/DepthComposer.lua")
    local Atmosphere = module(root, "hd2d/WorldAtmosphere.lua")
    local Renderer = module(root, "hd2d/Renderer.lua")

    local renderer = Renderer.new(Projection, Classifier)
    local relief = Relief.new(Classifier)
    local water = WaterSurface.new(Classifier)
    local occlusion = Occlusion.new()
    local depth = DepthComposer.new(relief, occlusion, WaterSurface)
    local atmosphere = Atmosphere.new()

    renderer.drawSolidRelief = function() return 0 end
    renderer.waterSurfaceZ = function(self)
      return WaterSurface.surfaceZ(self.level)
    end
    local drawWaterLight = renderer.drawWaterLight
    renderer.drawWaterLight = function(self, ctx, proj)
      water:draw(self, ctx, proj, self.level)
      drawWaterLight(self, ctx, proj)
    end
    renderer.drawActors = function(self, ctx, proj)
      return depth:draw(self, ctx, proj)
    end
    renderer:update(0, 2)

    local blocked = {}
    for y = 2, 3 do
      for x = 2, 4 do blocked[y * 32 + x] = "structure" end
    end
    for y = 0, 3 do
      for x = 8, 9 do blocked[y * 32 + x] = "vegetation" end
    end

    local map = {
      id = "SYNTHETIC_PALLET",
      def = { tileset = "OVERWORLD" },
      widthCells = 10,
      heightCells = 9,
    }

    function map:inBounds(x, y)
      return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
    end
    function map:isWaterCell(x, y) return y == 8 end
    function map:isGrassCell(x, y)
      return y >= 5 and y <= 6 and x >= 5 and x <= 7
    end
    function map:isWarpTileCell(x, y) return x == 3 and y == 4 end
    function map:warpAtCell(x, y)
      if self:isWarpTileCell(x, y) then return { index = 1 } end
      return nil
    end
    function map:isWalkableCell(x, y)
      if self:isWaterCell(x, y) then return false end
      return blocked[y * 32 + x] == nil
    end
    function map:cellTile(x, y)
      local kind = blocked[y * 32 + x]
      if kind == "vegetation" then return 0x52 end
      if kind == "structure" then return 0x30 + ((x + y) % 3) end
      if self:isWaterCell(x, y) then return 0x14 end
      return 0x01
    end

    local function drawPixelCell(x, y, kind)
      local px, py = x * CELL, y * CELL
      if kind == "water" then
        love.graphics.setColor(0.24, 0.48, 0.68, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.42, 0.67, 0.78, 1)
        love.graphics.rectangle("fill", px + 2, py + 4, 9, 2)
        love.graphics.rectangle("fill", px + 7, py + 11, 7, 2)
      elseif kind == "vegetation" then
        love.graphics.setColor(0.18, 0.38, 0.20, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.31, 0.55, 0.28, 1)
        love.graphics.rectangle("fill", px + 2, py + 2, 10, 6)
        love.graphics.setColor(0.12, 0.27, 0.16, 1)
        love.graphics.rectangle("fill", px + 5, py + 10, 7, 4)
      elseif kind == "structure" then
        love.graphics.setColor(0.68, 0.61, 0.43, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.80, 0.73, 0.53, 1)
        love.graphics.rectangle("fill", px + 2, py + 2, 12, 5)
        love.graphics.setColor(0.42, 0.28, 0.22, 1)
        love.graphics.rectangle("fill", px + 1, py + 12, 14, 3)
      elseif kind == "grass" then
        love.graphics.setColor(0.48, 0.64, 0.36, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.31, 0.49, 0.28, 1)
        for ix = 2, 12, 5 do
          love.graphics.rectangle("fill", px + ix, py + 8, 2, 5)
        end
      else
        love.graphics.setColor(0.56, 0.67, 0.43, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        if x >= 1 and x <= 6 and y == 4 then
          love.graphics.setColor(0.72, 0.66, 0.47, 1)
          love.graphics.rectangle("fill", px, py, CELL, CELL)
        end
      end
    end

    map.renderer = {}
    function map.renderer:drawBorderFill(camX, camY, vw, vh)
      love.graphics.setColor(0.12, 0.18, 0.12, 1)
      love.graphics.rectangle("fill", 0, 0, vw, vh)
    end
    function map.renderer:draw(camX, camY, vw, vh)
      love.graphics.push()
      love.graphics.translate(-camX, -camY)
      for y = 0, map.heightCells - 1 do
        for x = 0, map.widthCells - 1 do
          local kind = blocked[y * 32 + x]
          if map:isWaterCell(x, y) then kind = "water"
          elseif map:isGrassCell(x, y) then kind = "grass"
          elseif kind == nil then kind = "ground" end
          drawPixelCell(x, y, kind)
        end
      end
      love.graphics.pop()
    end
    function map.renderer:drawMapOnly(camX, camY, vw, vh)
      self:draw(camX, camY, vw, vh)
    end
    function map.renderer:drawCellBottom(cx, cy)
      love.graphics.setColor(0.24, 0.43, 0.22, 1)
      love.graphics.rectangle("fill", 0, 2, 16, 6)
      love.graphics.setColor(0.43, 0.65, 0.32, 1)
      love.graphics.rectangle("fill", 2, 0, 3, 7)
      love.graphics.rectangle("fill", 10, 1, 3, 7)
    end

    local actorImage = love.graphics.newCanvas(16, 20)
    love.graphics.setCanvas(actorImage)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(0.83, 0.20, 0.17, 1)
    love.graphics.rectangle("fill", 4, 1, 8, 4)
    love.graphics.setColor(0.89, 0.72, 0.55, 1)
    love.graphics.rectangle("fill", 5, 5, 6, 5)
    love.graphics.setColor(0.20, 0.34, 0.62, 1)
    love.graphics.rectangle("fill", 3, 10, 10, 7)
    love.graphics.setColor(0.16, 0.17, 0.20, 1)
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
    local actor = { id = "RED", cellX = 6, cellY = 6, px = 96, py = 96 }
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
      width = 640, height = 576,
      vw = 160, vh = 144,
      scale = 4,
      level = 2,
      state = state,
      cam = { x = 0, y = 0 },
      bgY = 0,
      paletteFor = function()
        return {
          { 245, 240, 210 }, { 170, 185, 132 },
          { 92, 110, 76 }, { 32, 39, 31 },
        }
      end,
      drawFx = function() end,
    }

    local raw = assert(renderer:drawWorld(ctx), "renderer returned no canvas")
    saveCanvas(raw, "hd2d-visual-raw.png")

    local proj = Projection.new(ctx, 2)
    local _, playerY = proj:projectWorld(actor.px + 8, actor.py + 16, 0)
    local focusY = playerY / raw:getHeight()
    local final = assert(atmosphere:present(raw, ctx, 2, focusY),
                         "atmosphere returned no canvas")
    saveCanvas(final, "hd2d-visual-depth.png")

    assert(relief.lastRoofs >= 1, "synthetic building generated no roof")
    assert(relief.lastCanopies >= 1, "synthetic vegetation generated no canopy")
    assert(relief.lastDoorways >= 1, "synthetic building generated no doorway")
    assert(relief.lastMassShadows >= 1, "synthetic masses generated no shadow")
    assert(water.lastRuns >= 1, "synthetic water generated no recessed run")
    assert(depth.lastActors == 1, "synthetic actor was not depth composed")
    assert(atmosphere.lastPasses == 1, "synthetic atmosphere pass missing")

    print("VISUAL_RAW=" .. love.filesystem.getSaveDirectory()
          .. "/hd2d-visual-raw.png")
    print("VISUAL_DEPTH=" .. love.filesystem.getSaveDirectory()
          .. "/hd2d-visual-depth.png")

    actorImage:release()
    atmosphere:invalidate()
    renderer:invalidate()
  end)

  if not ok then return fail(err) end
  print("PASS love_hd2d_visual_gate")
  love.event.quit(0)
end
