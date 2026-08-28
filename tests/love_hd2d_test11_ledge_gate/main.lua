local CELL = 16
local TILE = 8

local function fail(message)
  io.stderr:write("FAIL love_hd2d_test11_ledge_gate: " .. tostring(message) .. "\n")
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

local function paintTile(id, base, accent, dark)
  local x, y = tileXY(id)
  love.graphics.setColor(base[1], base[2], base[3], 1)
  love.graphics.rectangle("fill", x, y, TILE, TILE)
  if accent then
    love.graphics.setColor(accent[1], accent[2], accent[3], 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 6, 2)
    love.graphics.rectangle("fill", x + 2, y + 4, 5, 2)
  end
  if dark then
    love.graphics.setColor(dark[1], dark[2], dark[3], 1)
    love.graphics.rectangle("fill", x, y + 6, TILE, 2)
  end
end

local function paintIndexedTile(id, rows, palette)
  local ox, oy = tileXY(id)
  for y = 1, #rows do
    local row = rows[y]
    for x = 1, #row do
      local index = tonumber(row:sub(x, x)) or 0
      local c = palette[index + 1]
      love.graphics.setColor(c[1], c[2], c[3], 1)
      love.graphics.rectangle("fill", ox + x - 1, oy + y - 1, 1, 1)
    end
  end
end

function love.load()
  love.filesystem.setIdentity("krs-hd2d-test11-ledge-gate")
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
    renderer:update(0, 2)
    local atmosphere = Atmosphere.new()

    local LAWN, PATH, LEDGE = 0x2C, 0x39, 0x37
    local W, H = 12, 12
    local LEDGE_X0, LEDGE_X1 = 0, W - 1
    local LEDGE_Y1, LEDGE_Y2 = 4, 7

    local atlas = love.graphics.newCanvas(128, 48)
    love.graphics.setCanvas(atlas)
    love.graphics.clear(0.10, 0.12, 0.09, 1)
    paintTile(LAWN, {0.43,0.68,0.25}, {0.64,0.82,0.34}, {0.27,0.48,0.17})
    paintTile(PATH, {0.69,0.63,0.45}, {0.84,0.78,0.58}, {0.48,0.40,0.27})
    paintIndexedTile(LEDGE, {
      "02121210",
      "30311013",
      "33100133",
      "33100213",
      "31202011",
      "12020011",
      "11002100",
      "00022220",
    }, {
      {0.20,0.14,0.09},
      {0.39,0.29,0.17},
      {0.63,0.49,0.28},
      {0.83,0.75,0.54},
    })
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
      return x >= LEDGE_X0 and x <= LEDGE_X1
         and (y == LEDGE_Y1 or y == LEDGE_Y2)
    end

    local function tileForCell(x, y)
      if isLedgeCell(x, y) then return LEDGE end
      if y >= LEDGE_Y1 + 1 and y <= LEDGE_Y2 - 1 then return PATH end
      return LAWN
    end

    local map = {
      id = "SYNTHETIC_TEST11_ROUTE1_TERRACES",
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

    assert(LedgeTopology.logicalLevel(map, 5, 2) == 2,
           "upper terrace should be logical level 2")
    assert(LedgeTopology.logicalLevel(map, 5, 5) == 1,
           "middle terrace should be logical level 1")
    assert(LedgeTopology.logicalLevel(map, 5, 9) == 0,
           "lower terrace should be logical level 0")
    local face1 = assert(LedgeTopology.faceAt(map, 5, LEDGE_Y1), "first ledge face missing")
    local face2 = assert(LedgeTopology.faceAt(map, 5, LEDGE_Y2), "second ledge face missing")
    assert(face1.dir == "down" and face2.dir == "down", "ledge direction mismatch")
    assert(face1.upperLevel - face1.lowerLevel == 1, "first ledge is not one level")
    assert(face2.upperLevel - face2.lowerLevel == 1, "second ledge is not one level")

    local actorImage = love.graphics.newCanvas(16, 20)
    love.graphics.setCanvas(actorImage)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(0.83, 0.14, 0.10, 1)
    love.graphics.rectangle("fill", 4, 1, 8, 4)
    love.graphics.setColor(0.95, 0.74, 0.53, 1)
    love.graphics.rectangle("fill", 5, 5, 6, 5)
    love.graphics.setColor(0.14, 0.29, 0.65, 1)
    love.graphics.rectangle("fill", 3, 10, 10, 7)
    love.graphics.setColor(0.10, 0.11, 0.13, 1)
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
    local function actor(id, x, y)
      local a = { id = id, px = x * CELL, py = y * CELL }
      function a:pose() return sprite, self.px, self.py, "down", 0, false, false end
      return a
    end
    local topActor = actor("TOP", 5, 2)
    local midActor = actor("MID", 5, 5)
    local lowActor = actor("LOW", 5, 9)

    local state = {
      map = map, neighbors = {},
      entities = { topActor, midActor, lowActor }, ghosts = {}, player = midActor,
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

    local raw = assert(renderer:drawWorld(ctx), "TEST11 renderer returned no canvas")
    saveCanvas(raw, "hd2d-test11-ledge-raw.png")

    assert(flatCalls == 0, "TEST11 invoked flattened map renderer")
    assert((renderer.lastAtlasDirectFrames or 0) == 1, "TEST11 direct-atlas path inactive")
    assert((renderer.lastCompatibilityCaptureFrames or 0) == 0, "TEST11 used compatibility capture")
    assert((renderer.lastFlatSourceFallbacks or 0) == 0, "TEST11 leaked flat source")
    assert((renderer.lastAtlasMeshFallbacks or 0) == 0, "TEST11 atlas mesh fallback used")
    assert((renderer.lastTerrainSkirts or 0) == 0, "TEST11 semantic lawn/path skirts returned")
    assert((renderer.lastLedgeLevelCells or 0) > 0, "TEST11 ledge elevations inactive")
    assert((renderer.lastLedgeFaces or 0) == 24,
           "TEST11 expected exactly 24 ledge faces, got " .. tostring(renderer.lastLedgeFaces))
    assert((renderer.lastTexturedLedgeFaces or 0) == 24,
           "TEST11 ledge faces are not fully atlas-textured")
    assert((renderer.lastAtlasTileTextures or 0) >= 1,
           "TEST11 did not source ledge faces from exact 8x8 collision tiles")
    assert(renderer.lastActors == 3, "TEST11 terrace actors missing")

    local scenes = renderer:scenes(state)
    local zTop = renderer:surfaceZForWorld(scenes, topActor.px + 8, topActor.py + 12)
    local zMid = renderer:surfaceZForWorld(scenes, midActor.px + 8, midActor.py + 12)
    local zLow = renderer:surfaceZForWorld(scenes, lowActor.px + 8, lowActor.py + 12)
    assert(zTop > zMid and zMid > zLow, "TEST11 actor surfaces are not ordered by terrace")
    assert(math.abs((zTop - zMid) - LedgeTopology.STEP_WORLD) < 0.001,
           "TEST11 upper ledge height mismatch")
    assert(math.abs((zMid - zLow) - LedgeTopology.STEP_WORLD) < 0.001,
           "TEST11 lower ledge height mismatch")

    local proj = Projection.new(ctx, 2)
    local _, focusY = proj:worldPixel(midActor.px + 8, midActor.py + 12, zMid)
    local final = assert(atmosphere:present(raw, ctx, 2, focusY / raw:getHeight()),
                         "TEST11 atmosphere returned no canvas")
    saveCanvas(final, "hd2d-test11-ledge-depth.png")
  end)

  package.preload["hd2d.VanillaMotifs"] = nil
  package.preload["hd2d.LedgeTopology"] = nil
  if not ok then return fail(err) end
  print("PASS love_hd2d_test11_ledge_gate")
  love.event.quit(0)
end
