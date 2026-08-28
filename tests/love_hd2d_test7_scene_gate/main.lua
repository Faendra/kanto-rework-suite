local CELL = 16

local function fail(message)
  io.stderr:write("FAIL love_hd2d_test7_scene_gate: " .. tostring(message) .. "\n")
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
  love.filesystem.setIdentity("krs-hd2d-test7-scene-gate")
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local Projection = module(root, "hd2d/SceneProjection.lua")
    local Classifier = module(root, "hd2d/MaterialClassifier.lua")
    local SceneRenderer = module(root, "hd2d/SceneRenderer.lua")
    local SceneStyle = module(root, "hd2d/SceneStyle.lua")
    local LivePolish = module(root, "hd2d/LivePolish.lua")
    local VanillaMotifs = module(root, "hd2d/VanillaMotifs.lua")
    package.preload["hd2d.VanillaMotifs"] = function() return VanillaMotifs end
    local DioramaPolish = module(root, "hd2d/DioramaPolish.lua")
    local NaturalForms = module(root, "hd2d/NaturalForms.lua")
    local Continuity = module(root, "hd2d/SceneContinuity.lua")
    local TerrainRemaster = module(root, "hd2d/TerrainRemaster.lua")
    local Atmosphere = module(root, "hd2d/WorldAtmosphere.lua")

    local renderer = SceneStyle.apply(SceneRenderer.new(Projection, Classifier))
    renderer = LivePolish.apply(renderer)
    VanillaMotifs.install(Classifier)
    renderer = DioramaPolish.apply(renderer)
    renderer = NaturalForms.apply(renderer)
    renderer = Continuity.apply(renderer)
    renderer = TerrainRemaster.apply(renderer)
    renderer:update(0, 2)
    local atmosphere = Atmosphere.new()

    local TREE = { 0x2A, 0x2B, 0x3A, 0x3B }
    local BOULDER = { 0x40, 0x41, 0x50, 0x51 }
    local LAWN, PATH = 0x2C, 0x39

    local W, H = 14, 12
    local blocked = {}
    local function put(x, y, kind) blocked[y * 64 + x] = kind end

    -- Tall forest framing, separated from the central path.
    for y = 0, 10 do
      put(0, y, "tree")
      put(13, y, "tree")
    end
    for x = 1, 4 do put(x, 1, "tree") end
    for x = 9, 12 do put(x, 2, "tree") end

    -- One true vanilla boulder: unlike TEST6, trees must never take this path.
    put(4, 7, "boulder")

    -- Compact warp-backed building.
    for y = 4, 5 do
      for x = 8, 10 do put(x, y, "house") end
    end

    local map = {
      id = "SYNTHETIC_ROUTE_TEST7",
      def = { tileset = "OVERWORLD" },
      widthCells = W,
      heightCells = H,
    }
    function map:inBounds(x, y)
      return x >= 0 and y >= 0 and x < W and y < H
    end
    function map:isWaterCell() return false end
    function map:isGrassCell() return false end
    function map:isWarpTileCell(x, y) return x == 9 and y == 6 end
    function map:warpAtCell(x, y)
      if self:isWarpTileCell(x, y) then return { index = 1 } end
      return nil
    end
    function map:isWalkableCell(x, y)
      return blocked[y * 64 + x] == nil
    end
    function map:cellTile(x, y)
      local kind = blocked[y * 64 + x]
      if kind == "tree" then return 0x3A end
      if kind == "boulder" then return 0x50 end
      if kind == "house" then return 0x30 end
      return (x == 6 or x == 7 or y == 8) and PATH or LAWN
    end
    function map:tileAt(tx, ty)
      local cx, cy = math.floor(tx / 2), math.floor(ty / 2)
      local kind = blocked[cy * 64 + cx]
      local qi = (ty % 2) * 2 + (tx % 2) + 1
      if kind == "tree" then return TREE[qi] end
      if kind == "boulder" then return BOULDER[qi] end
      if kind == "house" then return 0x30 end
      return (cx == 6 or cx == 7 or cy == 8) and PATH or LAWN
    end
    function map:blockAt() return 0x01 end

    assert(VanillaMotifs.cellMotif(map, 0, 5) == "tree",
           "TEST7 canonical tree quartet was not recognized")
    assert(VanillaMotifs.cellMotif(map, 4, 7) == "boulder",
           "TEST7 canonical boulder quartet was not recognized")
    assert(VanillaMotifs.cellMotif(map, 3, 6) == "lawn",
           "TEST7 lawn quartet was not recognized")
    assert(VanillaMotifs.cellMotif(map, 6, 6) == "path",
           "TEST7 path quartet was not recognized")

    local function drawCell(x, y)
      local px, py = x * CELL, y * CELL
      local kind = blocked[y * 64 + x]
      local path = x == 6 or x == 7 or y == 8
      if path then
        love.graphics.setColor(0.76, 0.75, 0.62, 1)
      else
        love.graphics.setColor(0.49, 0.73, 0.30, 1)
      end
      love.graphics.rectangle("fill", px, py, CELL, CELL)

      if path then
        love.graphics.setColor(0.62, 0.58, 0.45, 1)
        love.graphics.rectangle("fill", px + 2, py + 5, 3, 2)
        love.graphics.rectangle("fill", px + 10, py + 11, 4, 2)
      else
        love.graphics.setColor(0.69, 0.84, 0.39, 1)
        love.graphics.rectangle("fill", px + 4, py + 5, 2, 2)
        love.graphics.rectangle("fill", px + 11, py + 10, 2, 2)
      end

      if kind == "tree" then
        love.graphics.setColor(0.08, 0.28, 0.10, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.25, 0.57, 0.20, 1)
        love.graphics.rectangle("fill", px + 2, py + 1, 12, 11)
        love.graphics.setColor(0.52, 0.79, 0.29, 1)
        love.graphics.rectangle("fill", px + 5, py + 2, 6, 5)
        love.graphics.setColor(0.20, 0.12, 0.07, 1)
        love.graphics.rectangle("fill", px + 7, py + 11, 3, 5)
      elseif kind == "boulder" then
        love.graphics.setColor(0.51, 0.55, 0.53, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.84, 0.86, 0.80, 1)
        love.graphics.rectangle("fill", px + 3, py + 2, 9, 6)
        love.graphics.setColor(0.29, 0.32, 0.32, 1)
        love.graphics.rectangle("fill", px + 2, py + 11, 12, 3)
      elseif kind == "house" then
        love.graphics.setColor(0.74, 0.80, 0.72, 1)
        love.graphics.rectangle("fill", px, py, CELL, CELL)
        love.graphics.setColor(0.31, 0.43, 0.42, 1)
        love.graphics.rectangle("fill", px, py, CELL, 5)
        love.graphics.setColor(0.78, 0.46, 0.12, 1)
        love.graphics.rectangle("fill", px + 5, py + 5, 6, 11)
      end
    end

    map.renderer = {}
    function map.renderer:drawBorderFill(camX, camY, vw, vh)
      love.graphics.setColor(0.18, 0.31, 0.17, 1)
      love.graphics.rectangle("fill", 0, 0, vw, vh)
    end
    function map.renderer:draw(camX, camY)
      love.graphics.push()
      love.graphics.translate(-camX, -camY)
      for y = 0, H - 1 do
        for x = 0, W - 1 do drawCell(x, y) end
      end
      love.graphics.pop()
    end
    function map.renderer:drawMapOnly(camX, camY, vw, vh)
      self:draw(camX, camY, vw, vh)
    end

    local actorImage = love.graphics.newCanvas(16, 20)
    love.graphics.setCanvas(actorImage)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(0.84, 0.14, 0.10, 1)
    love.graphics.rectangle("fill", 4, 1, 8, 4)
    love.graphics.setColor(0.93, 0.73, 0.53, 1)
    love.graphics.rectangle("fill", 5, 5, 6, 5)
    love.graphics.setColor(0.15, 0.30, 0.66, 1)
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
    local player = { id = "RED", px = 6 * CELL, py = 7 * CELL }
    function player:pose()
      return sprite, self.px, self.py, "down", 0, false, false
    end

    local state = {
      map = map, neighbors = {}, entities = { player }, ghosts = {}, player = player,
    }
    local ctx = {
      width = 960, height = 540, vw = 160, vh = 144, level = 2, scale = 4,
      state = state, cam = { x = 24, y = 16 }, bgY = 16,
      paletteFor = function()
        return {
          { 245, 240, 210 }, { 170, 190, 132 },
          { 92, 110, 76 }, { 32, 39, 31 },
        }
      end,
      drawFx = function() end,
    }

    local raw = assert(renderer:drawWorld(ctx), "TEST7 renderer returned no canvas")
    saveCanvas(raw, "hd2d-test7-route-raw.png")

    assert((renderer.lastRaisedLawnCells or 0) >= 35,
           "TEST7 did not raise enough lawn cells")
    assert((renderer.lastPathCells or 0) >= 15,
           "TEST7 did not preserve a distinct low path")
    assert((renderer.lastTerrainSkirts or 0) >= 8,
           "TEST7 lawn/path boundary emitted too little vertical terrain relief")
    assert((renderer.lastNaturalVegetationCards or 0) >= 8,
           "TEST7 canonical trees did not become upright pixel silhouettes")
    assert((renderer.lastNaturalBoundaryCards or 0) == 1,
           "TEST7 must produce exactly one canonical 3D boulder")
    assert(renderer.lastActors == 1,
           "TEST7 player did not remain attached to remastered terrain")

    local tree = Classifier.classify(map, 0, 5)
    local rock = Classifier.classify(map, 4, 7)
    assert(tree.family == "vegetation" and tree.motif == "tree",
           "TEST7 live classifier relabelled vanilla tree incorrectly")
    assert(rock.family == "boundary" and rock.motif == "boulder",
           "TEST7 live classifier relabelled vanilla boulder incorrectly")

    local scenes = renderer:scenes(state)
    local lawnZ = renderer:surfaceZForWorld(scenes, 3 * CELL + 8, 6 * CELL + 8)
    local pathZ = renderer:surfaceZForWorld(scenes, 6 * CELL + 8, 6 * CELL + 8)
    assert(lawnZ > pathZ + 0.05,
           "TEST7 lawn and path are still effectively coplanar")

    local proj = Projection.new(ctx, 2)
    local focusZ = renderer:surfaceZForWorld(scenes, player.px + 8, player.py + 12)
    local _, playerY = proj:worldPixel(player.px + 8, player.py + 12, focusZ)
    local final = assert(atmosphere:present(raw, ctx, 2, playerY / raw:getHeight()),
                         "TEST7 atmosphere returned no canvas")
    saveCanvas(final, "hd2d-test7-route-depth.png")
  end)

  package.preload["hd2d.VanillaMotifs"] = nil
  if not ok then return fail(err) end
  print("PASS love_hd2d_test7_scene_gate")
  love.event.quit(0)
end
