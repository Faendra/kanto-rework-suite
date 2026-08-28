local CELL = 16
local TILE = 8

local function fail(message)
  io.stderr:write("FAIL love_hd2d_test8_atlas_gate: " .. tostring(message) .. "\n")
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
    love.graphics.rectangle("fill", x + 1, y + 1, 5, 2)
    love.graphics.rectangle("fill", x + 3, y + 4, 4, 2)
  end
  if dark then
    love.graphics.setColor(dark[1], dark[2], dark[3], 1)
    love.graphics.rectangle("fill", x, y + 6, 8, 2)
  end
end

-- Paint four atlas tiles that compose into a 16x16 tree with a bright outer
-- background and a dark central crown. TEST8 can therefore prove that the
-- runtime mask removes edge-connected background instead of simply drawing a
-- rectangular 16x16 card.
local function paintTreeTile(id, qx, qy)
  local x, y = tileXY(id)
  love.graphics.setColor(0.74, 0.82, 0.60, 1)
  love.graphics.rectangle("fill", x, y, TILE, TILE)

  local ix = qx == 0 and 2 or 0
  local iy = qy == 0 and 2 or 0
  love.graphics.setColor(0.08, 0.29, 0.10, 1)
  love.graphics.rectangle("fill", x + ix, y + iy, 6, 6)
  love.graphics.setColor(0.30, 0.61, 0.20, 1)
  love.graphics.rectangle("fill", x + ix + 1, y + iy + 1, 4, 2)
  love.graphics.setColor(0.14, 0.17, 0.08, 1)
  love.graphics.rectangle("fill", x + ix + 2, y + iy + 4, 3, 2)
end

function love.load()
  love.filesystem.setIdentity("krs-hd2d-test8-atlas-gate")
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
    renderer = AtlasWorld.apply(renderer, AtlasSource)
    renderer = Continuity.apply(renderer)
    renderer = TerrainRemaster.apply(renderer)
    renderer:update(0, 2)
    local atmosphere = Atmosphere.new()

    -- Verified directly against generated/tilesets/overworld.png:
    -- 40/41/50/51 = dense tree/foliage; 2A/2B/3A/3B = round boulder.
    local TREE = { 0x40, 0x41, 0x50, 0x51 }
    local BOULDER = { 0x2A, 0x2B, 0x3A, 0x3B }
    local LAWN, PATH, HOUSE = 0x2C, 0x39, 0x30
    local W, H = 14, 12

    local atlas = love.graphics.newCanvas(128, 48)
    love.graphics.setCanvas(atlas)
    love.graphics.clear(0.11, 0.14, 0.12, 1)

    paintTile(LAWN, {0.42, 0.68, 0.25}, {0.68, 0.84, 0.37}, {0.27, 0.49, 0.19})
    paintTile(PATH, {0.70, 0.66, 0.50}, {0.84, 0.80, 0.62}, {0.52, 0.47, 0.34})
    paintTile(HOUSE, {0.73, 0.78, 0.70}, {0.32, 0.45, 0.44}, {0.55, 0.36, 0.17})

    paintTreeTile(TREE[1], 0, 0)
    paintTreeTile(TREE[2], 1, 0)
    paintTreeTile(TREE[3], 0, 1)
    paintTreeTile(TREE[4], 1, 1)

    paintTile(BOULDER[1], {0.48,0.51,0.49}, {0.80,0.82,0.77}, {0.29,0.31,0.31})
    paintTile(BOULDER[2], {0.54,0.56,0.53}, {0.86,0.87,0.81}, {0.31,0.33,0.33})
    paintTile(BOULDER[3], {0.43,0.46,0.45}, {0.72,0.75,0.72}, {0.24,0.27,0.28})
    paintTile(BOULDER[4], {0.50,0.53,0.51}, {0.82,0.83,0.78}, {0.27,0.30,0.30})
    love.graphics.setCanvas()
    atlas:setFilter("nearest", "nearest")

    local quads = {}
    for t = 0, 95 do
      quads[t] = love.graphics.newQuad((t % 16) * TILE,
                                       math.floor(t / 16) * TILE,
                                       TILE, TILE, 128, 48)
    end

    local forbiddenFlatCalls = 0
    local mapRenderer = { image = atlas, quads = quads }
    function mapRenderer:drawBorderFill() forbiddenFlatCalls = forbiddenFlatCalls + 1 end
    function mapRenderer:draw() forbiddenFlatCalls = forbiddenFlatCalls + 1 end
    function mapRenderer:drawMapOnly() forbiddenFlatCalls = forbiddenFlatCalls + 1 end
    function mapRenderer:drawCellBottom() forbiddenFlatCalls = forbiddenFlatCalls + 1 end

    local blocked = {}
    local function put(x, y, kind) blocked[y * 64 + x] = kind end
    for y = 0, 10 do put(0, y, "tree"); put(13, y, "tree") end
    for x = 1, 4 do put(x, 1, "tree") end
    for x = 9, 12 do put(x, 2, "tree") end
    put(4, 7, "boulder")
    for y = 4, 5 do for x = 8, 10 do put(x, y, "house") end end

    local map = {
      id = "SYNTHETIC_TEST8_ATLAS_ROUTE",
      def = { tileset = "OVERWORLD" },
      widthCells = W, heightCells = H, renderer = mapRenderer,
    }
    function map:inBounds(x, y) return x >= 0 and y >= 0 and x < W and y < H end
    function map:isWaterCell() return false end
    function map:isGrassCell() return false end
    function map:isWarpTileCell(x, y) return x == 9 and y == 6 end
    function map:warpAtCell(x, y)
      if self:isWarpTileCell(x, y) then return { index = 1 } end
      return nil
    end
    function map:isWalkableCell(x, y) return blocked[y * 64 + x] == nil end
    function map:cellTile(x, y)
      local kind = blocked[y * 64 + x]
      if kind == "tree" then return TREE[3] end
      if kind == "boulder" then return BOULDER[3] end
      if kind == "house" then return HOUSE end
      return (x == 6 or x == 7 or y == 8) and PATH or LAWN
    end
    function map:tileAt(tx, ty)
      local cx, cy = math.floor(tx / 2), math.floor(ty / 2)
      local kind = blocked[cy * 64 + cx]
      local qi = (ty % 2) * 2 + (tx % 2) + 1
      if kind == "tree" then return TREE[qi] end
      if kind == "boulder" then return BOULDER[qi] end
      if kind == "house" then return HOUSE end
      return (cx == 6 or cx == 7 or cy == 8) and PATH or LAWN
    end
    function map:blockAt() return 0x01 end

    assert(VanillaMotifs.cellMotif(map, 0, 5) == "tree",
           "TEST8 canonical tree quartet was not recognized")
    assert(VanillaMotifs.cellMotif(map, 4, 7) == "boulder",
           "TEST8 canonical boulder quartet was not recognized")

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

    local actorQuad = love.graphics.newQuad(0, 0, 16, 20, 16, 20)
    local sprite = {
      getPoseGeometry = function()
        return { quad = actorQuad, width = 16, height = 20,
                 anchorX = 8, anchorY = 20, mirror = false }
      end,
      resolveImage = function() return actorImage end,
    }
    local player = { id = "RED", px = 6 * CELL, py = 7 * CELL }
    function player:pose() return sprite, self.px, self.py, "down", 0, false, false end

    local state = {
      map = map, neighbors = {}, entities = { player }, ghosts = {}, player = player,
    }
    local ctx = {
      width = 960, height = 540, vw = 160, vh = 144,
      level = 2, scale = 4, state = state,
      cam = { x = 24, y = 16 }, bgY = 16,
      paletteFor = function()
        return { {245,240,210}, {170,190,132}, {92,110,76}, {32,39,31} }
      end,
      drawFx = function() end,
    }

    local raw = assert(renderer:drawWorld(ctx),
                       "TEST8 direct-atlas renderer returned no canvas")
    saveCanvas(raw, "hd2d-test8-atlas-raw.png")

    assert(forbiddenFlatCalls == 0,
           "TEST8 invoked flattened Gen1Recomp map rendering")
    assert((renderer.lastAtlasDirectFrames or 0) == 1,
           "TEST8 did not select direct runtime-atlas path")
    assert((renderer.lastCompatibilityCaptureFrames or 0) == 0,
           "TEST8 unexpectedly used compatibility capture")
    assert((renderer.lastFlatSourceFallbacks or 0) == 0,
           "TEST8 leaked to flattened framebuffer textures")
    assert((renderer.lastAtlasMeshFallbacks or 0) == 0,
           "TEST8 real LÖVE failed to rasterize direct atlas meshes")
    assert((renderer.lastAtlasGroundCells or 0) >= 50,
           "TEST8 did not atlas-texture enough terrain cells")
    assert((renderer.lastAtlasDonorGroundCells or 0) >= 8,
           "TEST8 did not replace object footprints with atlas donor ground")
    assert((renderer.lastAtlasNaturalObjects or 0) >= 8,
           "TEST8 natural objects are not using runtime atlas pixels")
    assert((renderer.lastAtlasStructures or 0) >= 1,
           "TEST8 structure is not using a runtime-atlas region")
    assert((renderer.lastAtlasRegionTextures or 0) >= 1,
           "TEST8 created no direct architecture atlas region")
    assert((renderer.lastNaturalVegetationCards or 0) >= 8,
           "TEST8 trees did not become upright pixel silhouettes")
    assert((renderer.lastNaturalSilhouetteBillboards or 0) >= 8,
           "TEST8 trees did not use aspect-preserving pixel billboards")
    assert((renderer.lastNaturalSilhouettePixelsCleared or 0) > 0,
           "TEST8 tree mask removed no edge-connected background pixels")
    assert((renderer.lastNaturalCardFallbacks or 0) == 0,
           "TEST8 fell back to legacy octagonal natural-form geometry")
    assert((renderer.lastNaturalBoundaryCards or 0) == 1,
           "TEST8 should render exactly one canonical boulder")
    assert((renderer.lastRaisedLawnCells or 0) >= 35,
           "TEST8 did not keep raised lawn terrain")
    assert((renderer.lastTerrainSkirts or 0) >= 8,
           "TEST8 lost lawn/path edge relief")
    assert(renderer.lastActors == 1,
           "TEST8 player did not remain depth-composed")

    local scenes = renderer:scenes(state)
    local proj = Projection.new(ctx, 2)
    local focusZ = renderer:surfaceZForWorld(scenes, player.px + 8, player.py + 12)
    local _, playerY = proj:worldPixel(player.px + 8, player.py + 12, focusZ)
    local final = assert(atmosphere:present(raw, ctx, 2, playerY / raw:getHeight()),
                         "TEST8 atmosphere returned no canvas")
    saveCanvas(final, "hd2d-test8-atlas-depth.png")
  end)

  package.preload["hd2d.VanillaMotifs"] = nil
  if not ok then return fail(err) end
  print("PASS love_hd2d_test8_atlas_gate")
  love.event.quit(0)
end
