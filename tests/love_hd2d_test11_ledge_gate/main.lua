local CELL = 16
local TILE = 8

local function fail(message)
  io.stderr:write("FAIL love_hd2d_test13_ledge_local_gate: " .. tostring(message) .. "\n")
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

local function tileXY(id)
  return (id % 16) * TILE, math.floor(id / 16) * TILE
end

local function paintTile(id, color)
  local x, y = tileXY(id)
  love.graphics.setColor(color[1], color[2], color[3], 1)
  love.graphics.rectangle("fill", x, y, TILE, TILE)
end

function love.load()
  love.filesystem.setIdentity("krs-hd2d-test13-ledge-local-gate")
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local Projection = module(root, "hd2d/SceneProjection.lua")
    local Classifier = module(root, "hd2d/MaterialClassifier.lua")
    local SceneRenderer = module(root, "hd2d/SceneRenderer.lua")
    local SceneStyle = module(root, "hd2d/SceneStyle.lua")
    local LivePolish = module(root, "hd2d/LivePolish.lua")
    local VanillaMotifs = module(root, "hd2d/VanillaMotifs.lua")
    local LedgeTopology = module(root, "hd2d/LedgeTopology.lua")
    package.preload["hd2d.VanillaMotifs"] = function() return VanillaMotifs end
    package.preload["hd2d.LedgeTopology"] = function() return LedgeTopology end
    local DioramaPolish = module(root, "hd2d/DioramaPolish.lua")
    local NaturalForms = module(root, "hd2d/NaturalForms.lua")
    local NaturalScale = module(root, "hd2d/NaturalScale.lua")
    local AtlasSource = module(root, "hd2d/AtlasSource.lua")
    local AtlasWorld = module(root, "hd2d/AtlasWorld.lua")
    local Continuity = module(root, "hd2d/SceneContinuity.lua")
    local TerrainRemaster = module(root, "hd2d/TerrainRemaster.lua")
    local LedgeHopSmoothing = module(root, "hd2d/LedgeHopSmoothing.lua")
    local Atmosphere = module(root, "hd2d/WorldAtmosphere.lua")

    local renderer = SceneStyle.apply(SceneRenderer.new(Projection, Classifier))
    renderer = LivePolish.apply(renderer)
    VanillaMotifs.install(Classifier)
    renderer = DioramaPolish.apply(renderer)
    renderer = NaturalForms.apply(renderer)
    renderer = NaturalScale.apply(renderer)
    renderer = AtlasWorld.apply(renderer, AtlasSource)
    renderer = Continuity.apply(renderer)
    renderer = TerrainRemaster.apply(renderer)
    renderer = LedgeHopSmoothing.apply(renderer)
    renderer:update(0, 2)
    local atmosphere = Atmosphere.new()

    local LAWN, PATH, LEDGE = 0x2C, 0x39, 0x37
    local W, H = 12, 12
    local LEDGE_Y1, LEDGE_Y2 = 4, 7

    local atlas = love.graphics.newCanvas(128, 48)
    love.graphics.setCanvas(atlas)
    love.graphics.clear(0.10, 0.12, 0.09, 1)
    paintTile(LAWN, {0.43,0.68,0.25})
    paintTile(PATH, {0.69,0.63,0.45})
    paintTile(LEDGE, {0.63,0.49,0.28})
    love.graphics.setCanvas()
    atlas:setFilter("nearest", "nearest")

    local quads = {}
    for t = 0, 95 do
      quads[t] = love.graphics.newQuad((t % 16) * TILE,
                                       math.floor(t / 16) * TILE,
                                       TILE, TILE, 128, 48)
    end

    local flatCalls = 0
    local mapRenderer = { image = atlas, quads = quads }
    function mapRenderer:drawBorderFill() flatCalls = flatCalls + 1 end
    function mapRenderer:draw() flatCalls = flatCalls + 1 end
    function mapRenderer:drawMapOnly() flatCalls = flatCalls + 1 end
    function mapRenderer:drawCellBottom() flatCalls = flatCalls + 1 end

    local function isLedgeCell(x, y)
      return x >= 0 and x < W and (y == LEDGE_Y1 or y == LEDGE_Y2)
    end
    local function tileForCell(x, y)
      if isLedgeCell(x, y) then return LEDGE end
      if y >= LEDGE_Y1 + 1 and y <= LEDGE_Y2 - 1 then return PATH end
      return LAWN
    end

    local map = {
      id = "SYNTHETIC_TEST13_LOCAL_LEDGES",
      def = { tileset = "OVERWORLD" },
      widthCells = W, heightCells = H, renderer = mapRenderer,
    }
    function map:inBounds(x, y) return x >= 0 and y >= 0 and x < W and y < H end
    function map:isWaterCell() return false end
    function map:isGrassCell() return false end
    function map:isWarpTileCell() return false end
    function map:warpAtCell() return nil end
    function map:isWalkableCell(x, y) return not isLedgeCell(x, y) end
    function map:cellTile(x, y) return tileForCell(x, y) end
    function map:tileAt(tx, ty)
      return tileForCell(math.floor(tx / 2), math.floor(ty / 2))
    end
    function map:blockAt() return 0x01 end

    for _, p in ipairs({ {5,2}, {5,5}, {5,9}, {1,1}, {10,10} }) do
      assert(LedgeTopology.logicalLevel(map, p[1], p[2]) == 0,
             "vanilla ledge leaked a global logical terrain level")
      assert(math.abs(LedgeTopology.worldZ(map, p[1], p[2])) < 0.00001,
             "vanilla ledge leaked global world Z")
    end

    local face1 = assert(LedgeTopology.faceAt(map, 5, LEDGE_Y1), "first local ledge face missing")
    local face2 = assert(LedgeTopology.faceAt(map, 5, LEDGE_Y2), "second local ledge face missing")
    assert(face1.dir == "down" and face2.dir == "down", "ledge direction mismatch")
    assert(face1.upperLevel - face1.lowerLevel == 1,
           "ledge visual lip is not one local level")
    assert(math.abs((face1.upperZ - face1.lowerZ) - LedgeTopology.STEP_WORLD) < 0.0001,
           "ledge local visual height mismatch")

    local hopProbe = {
      ledgeHop = true, hopTotal = 32, hopFrames = 8,
      facing = "down", px = 5 * CELL, py = 4 * CELL + 8,
    }
    assert(LedgeTopology.hopWorldZ(map, hopProbe) == nil,
           "ledge hop invented a persistent terrain baseline")

    local actorImage = love.graphics.newCanvas(16, 20)
    love.graphics.setCanvas(actorImage)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(0.83, 0.14, 0.10, 1)
    love.graphics.rectangle("fill", 4, 1, 8, 18)
    love.graphics.setCanvas()
    local actorQuad = love.graphics.newQuad(0, 0, 16, 20, 16, 20)
    local sprite = {
      getPoseGeometry = function()
        return { quad = actorQuad, width = 16, height = 20,
                 anchorX = 8, anchorY = 20, mirror = false }
      end,
      resolveImage = function() return actorImage end,
    }
    local function actor(id, x, y)
      local a = { id = id, px = x * CELL, py = y * CELL }
      function a:pose() return sprite, self.px, self.py, "down", 0, false, false end
      return a
    end
    local topActor = actor("TOP", 5, 2)
    local midActor = actor("MID", 5, 5)
    local lowActor = actor("LOW", 5, 9)
    local state = {
      map = map, neighbors = {}, entities = { topActor, midActor, lowActor },
      ghosts = {}, player = midActor,
    }
    local ctx = {
      width = 960, height = 540, vw = 160, vh = 144,
      level = 2, scale = 4, state = state,
      cam = { x = 16, y = 12 }, bgY = 12,
      paletteFor = function()
        return { {245,240,210}, {170,190,132}, {92,110,76}, {32,39,31} }
      end,
      drawFx = function() end,
    }

    local raw = assert(renderer:drawWorld(ctx), "TEST13 renderer returned no canvas")
    saveCanvas(raw, "hd2d-test11-ledge-raw.png")

    assert(flatCalls == 0, "TEST13 invoked flattened map renderer")
    assert((renderer.lastAtlasDirectFrames or 0) == 1, "TEST13 direct-atlas path inactive")
    assert((renderer.lastTerrainSkirts or 0) == 0, "TEST13 semantic skirts returned")
    assert((renderer.lastLedgeLevelCells or 0) == 0,
           "TEST13 still raises terrain cells from ledges")
    assert((renderer.lastLedgeFaces or 0) == 24,
           "TEST13 expected exactly 24 local ledge faces")
    assert((renderer.lastTexturedLedgeFaces or 0) == 24,
           "TEST13 local ledge faces are not atlas-textured")
    assert((renderer.lastSmoothedLedgeActors or 0) == 0,
           "TEST13 still applies global hop baseline smoothing")

    local scenes = renderer:scenes(state)
    local zTop = renderer:surfaceZForWorld(scenes, topActor.px + 8, topActor.py + 12)
    local zMid = renderer:surfaceZForWorld(scenes, midActor.px + 8, midActor.py + 12)
    local zLow = renderer:surfaceZForWorld(scenes, lowActor.px + 8, lowActor.py + 12)
    assert(math.abs(zTop - zMid) < 0.00001 and math.abs(zMid - zLow) < 0.00001,
           "TEST13 ledges still create random actor/world elevation")

    local _, playerY = Projection.new(ctx, 2):worldPixel(midActor.px + 8,
                                                         midActor.py + 12, zMid)
    local final = assert(atmosphere:present(raw, ctx, 2, playerY / raw:getHeight()),
                         "TEST13 atmosphere returned no canvas")
    saveCanvas(final, "hd2d-test11-ledge-depth.png")
  end)

  package.preload["hd2d.VanillaMotifs"] = nil
  package.preload["hd2d.LedgeTopology"] = nil
  if not ok then return fail(err) end
  print("PASS love_hd2d_test13_ledge_local_gate")
  love.event.quit(0)
end
