local function fail(message)
  io.stderr:write("FAIL love_hd2d_natural_forms_gate: " .. tostring(message) .. "\n")
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
  love.filesystem.setIdentity("krs-hd2d-natural-forms-gate")
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local Projection = module(root, "hd2d/SceneProjection.lua")
    local VanillaMotifs = module(root, "hd2d/VanillaMotifs.lua")
    package.preload["hd2d.VanillaMotifs"] = function() return VanillaMotifs end
    local NaturalForms = module(root, "hd2d/NaturalForms.lua")
    local NaturalScale = module(root, "hd2d/NaturalScale.lua")
    local SceneContinuity = module(root, "hd2d/SceneContinuity.lua")

    -- Verified directly from Pokemon Red generated/tilesets/overworld.png.
    local TREE = { 0x40, 0x41, 0x50, 0x51 }
    local BOULDER = { 0x2A, 0x2B, 0x3A, 0x3B }
    local map = {
      def = { tileset = "OVERWORLD" },
      widthCells = 8,
      heightCells = 8,
    }
    function map:tileAt(tx, ty)
      local cx, cy = math.floor(tx / 2), math.floor(ty / 2)
      local qi = (ty % 2) * 2 + (tx % 2) + 1
      if cx == 1 and cy == 1 then return TREE[qi] end
      if cx == 3 and cy == 1 then return BOULDER[qi] end
      return 0x2C
    end

    assert(VanillaMotifs.cellMotif(map, 1, 1) == "tree",
           "canonical tree quartet was not recognized")
    assert(VanillaMotifs.cellMotif(map, 3, 1) == "boulder",
           "canonical boulder quartet was not recognized")

    local ctx = {
      width = 800,
      height = 450,
      vw = 160,
      vh = 144,
      state = { map = map, player = { px = 64, py = 64 } },
      cam = { x = 0, y = 0 },
      bgY = 0,
    }
    local proj = Projection.new(ctx, 2)

    local source = love.graphics.newCanvas(128, 128)
    love.graphics.setCanvas(source)
    love.graphics.clear(0.42, 0.66, 0.30, 1)
    love.graphics.setColor(0.08, 0.30, 0.12, 1)
    love.graphics.rectangle("fill", 16, 16, 16, 16)
    love.graphics.setColor(0.34, 0.70, 0.27, 1)
    love.graphics.rectangle("fill", 19, 18, 10, 9)
    love.graphics.setColor(0.58, 0.82, 0.35, 1)
    love.graphics.rectangle("fill", 22, 18, 5, 4)
    love.graphics.setColor(0.50, 0.54, 0.52, 1)
    love.graphics.rectangle("fill", 48, 16, 16, 16)
    love.graphics.setColor(0.82, 0.84, 0.78, 1)
    love.graphics.rectangle("fill", 51, 18, 9, 6)
    love.graphics.setColor(0.28, 0.31, 0.31, 1)
    love.graphics.rectangle("fill", 50, 27, 11, 3)
    love.graphics.setCanvas()
    source:setFilter("nearest", "nearest")

    local boulderTexture = love.graphics.newCanvas(16, 16)
    love.graphics.setCanvas(boulderTexture)
    love.graphics.clear(0.48, 0.51, 0.49, 1)
    love.graphics.setColor(0.82, 0.84, 0.78, 1)
    love.graphics.rectangle("fill", 3, 2, 9, 6)
    love.graphics.setColor(0.28, 0.31, 0.31, 1)
    love.graphics.rectangle("fill", 2, 11, 12, 3)
    love.graphics.setCanvas()
    boulderTexture:setFilter("nearest", "nearest")

    local fallbackVegetation = 0
    local fallbackBoundary = 0
    local fake = {
      source = source,
      sourceW = 128,
      sourceH = 128,
      sourceCamX = 0,
      sourceCamY = 0,
      resetMetrics = function() end,
      invalidate = function() end,
      drawVegetation = function()
        fallbackVegetation = fallbackVegetation + 1
      end,
      drawLowPrism = function()
        fallbackBoundary = fallbackBoundary + 1
      end,
    }
    NaturalForms.apply(fake)
    NaturalScale.apply(fake)
    fake:resetMetrics()

    local scene = { map = map, ox = 0, oy = 0 }
    local output = love.graphics.newCanvas(800, 450)
    love.graphics.setCanvas(output)
    love.graphics.clear(0.64, 0.78, 0.84, 1)
    fake:drawVegetation(proj, { x = 1, y = 1, scene = scene })
    fake:drawLowPrism(proj,
      { x = 3, y = 1, scene = scene, atlasTexture = boulderTexture },
      0.18, { 0.6, 0.6, 0.6 })
    love.graphics.setCanvas()

    assert(fake.lastNaturalVegetationCards == 1,
           "vegetation did not use source-textured upright natural card")
    assert((fake.lastOrganicTreeOffsets or 0) == 1,
           "TEST12 tree projection variation was not exercised")
    assert((fake.lastScaledTrees or 0) == 1,
           "TEST12 tree scale tuning was not exercised")
    assert((fake.lastFlattenedBoulders or 0) == 1,
           "TEST12 canonical boulder was not intercepted by NaturalScale")
    assert((fake.lastSlopedBoulders or 0) == 1,
           "TEST12 boulder did not use the sloped mound geometry")
    assert((fake.lastNaturalBoundaryCards or 0) == 0,
           "TEST12 boulder fell through to the old octagonal natural form")
    assert((fake.lastNaturalCardFallbacks or 0) == 0,
           "natural forms unexpectedly fell back to old geometry")
    assert(fallbackVegetation == 0 and fallbackBoundary == 0,
           "old vegetation/boundary geometry was still called")
    saveCanvas(output, "hd2d-natural-forms.png")

    local playerActor = {}
    local remoteActor = {}
    local continuity = {
      resetMetrics = function() end,
      buildScene = function()
        return {
          { x = 4, y = 4 },
          { x = 4, y = 5 },
        }, {
          { kind = "actor", actor = playerActor, basePx = 4 * 16, basePy = 4 * 16, ox = 0, oy = 0 },
          { kind = "actor", actor = remoteActor, basePx = 30 * 16, basePy = 30 * 16, ox = 0, oy = 0 },
        }, {}
      end,
    }
    SceneContinuity.apply(continuity)
    continuity:resetMetrics()
    local _, objects = continuity:buildScene({ state = { player = playerActor } }, proj)
    assert(#objects == 1 and objects[1].actor == playerActor,
           "unsupported connected-map actor was not culled")
    assert(continuity.lastCulledUnsupportedActors == 1,
           "continuity cull metric did not record unsupported actor")
  end)

  package.preload["hd2d.VanillaMotifs"] = nil
  if not ok then return fail(err) end
  print("PASS love_hd2d_natural_forms_gate")
  love.event.quit(0)
end
