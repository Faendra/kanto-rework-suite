local function fail(message)
  io.stderr:write("FAIL love_hd2d_live_polish_gate: " .. tostring(message) .. "\n")
  love.event.quit(1)
end

local function module(root, rel)
  local ok, result = pcall(dofile, root .. "/packages/kanto_rework_hd2d_world/" .. rel)
  if not ok then error(result, 0) end
  return result
end

function love.load()
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local Projection = module(root, "hd2d/SceneProjection.lua")
    local Classifier = module(root, "hd2d/MaterialClassifier.lua")
    local LivePolish = module(root, "hd2d/LivePolish.lua")
    local DioramaPolish = module(root, "hd2d/DioramaPolish.lua")

    local solid = { [0] = true, [1] = true, [8] = true, [9] = true }
    local map = {
      def = { tileset = "OVERWORLD" },
      widthCells = 8,
      heightCells = 8,
      renderer = {},
    }
    function map:inBounds(x, y)
      return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
    end
    function map:isWaterCell() return false end
    function map:isGrassCell() return false end
    function map:isWarpTileCell() return false end
    function map:warpAtCell() return nil end
    function map:isWalkableCell(x, y) return not solid[y * 8 + x] end
    function map:cellTile() return 0x3D end
    function map:blockAt() return 0x0F end

    local fake = {
      MaterialClassifier = Classifier,
      resetMetrics = function() end,
      drawBackdrop = function() end,
      drawActor = function(self, proj)
        self._actorScale = proj.spriteScale
        return true
      end,
      drawVegetation = function(self, proj)
        self._vegetationWidth = proj.tileW
        local _, by = proj:cell(4, 4, 0)
        local _, ty = proj:cell(4, 4, 1)
        self._vegetationRise = math.abs(ty - by)
        return true
      end,
      drawLowPrism = function(self, proj, cmd, height)
        self._boundaryWidth = proj.tileW
        self._boundaryHeight = height
        local _, by = proj:cell(cmd.x + 0.5, cmd.y + 0.5, 0)
        local _, ty = proj:cell(cmd.x + 0.5, cmd.y + 0.5, height)
        self._boundaryRise = math.abs(ty - by)
        return true
      end,
      drawStructure = function(self, proj)
        local _, by = proj:cell(4, 4, 0)
        local _, ty = proj:cell(4, 4, 1)
        self._structureRise = math.abs(ty - by)
        return true
      end,
    }
    DioramaPolish.apply(LivePolish.apply(fake))

    local material = Classifier.classify(map, 0, 0)
    assert(material.kind == "solid" and material.family == "vegetation",
           "vanilla OVERWORLD tree-wall block was not promoted to vegetation")

    local ctx = {
      width = 960, height = 540, vw = 160, vh = 144,
      cam = { x = 0, y = 0 }, bgY = 0,
      state = { map = map, player = { px = 64, py = 64 } },
      paletteFor = function()
        return { {245,240,210}, {170,185,132}, {92,110,76}, {32,39,31} }
      end,
    }
    local proj = Projection.new(ctx, 2)
    assert((proj.elevation / math.max(0.001, proj.tileH)) >= 2.0,
           "TEST5 DEPTH camera remains too top-down")

    local _, base0 = proj:cell(4, 4, 0)
    local _, base1 = proj:cell(4, 4, 1)
    local baseRise = math.abs(base1 - base0)

    local nearRow = { map = map, basePx = 64, basePy = 96, px = 64, py = 96, ox = 0, oy = 0 }
    local farRow = { map = map, basePx = 64, basePy = 0, px = 64, py = 0, ox = 0, oy = 0 }
    fake:drawActor(proj, nearRow)
    local nearScale = assert(fake._actorScale, "near actor scale missing")
    fake:drawActor(proj, farRow)
    local farScale = assert(fake._actorScale, "far actor scale missing")
    assert(nearScale > farScale * 1.05,
           "actor billboards are not shrinking with perspective depth")

    fake:drawVegetation(proj, { x = 4, y = 6 })
    local nearTree = assert(fake._vegetationWidth, "near vegetation width missing")
    local treeRise = assert(fake._vegetationRise, "vegetation vertical rise missing")
    assert(treeRise > baseRise * 1.35,
           "TEST5 vegetation is not materially taller on screen")
    fake:drawVegetation(proj, { x = 4, y = 0 })
    local farTree = assert(fake._vegetationWidth, "far vegetation width missing")
    assert(nearTree > farTree * 1.05,
           "vegetation silhouettes are not shrinking with perspective depth")

    local structureCmd = {
      mass = { minX = 3, maxX = 5, minY = 3, maxY = 4 },
      scene = { ox = 0, oy = 0 },
    }
    fake:drawStructure(proj, structureCmd)
    assert((fake._structureRise or 0) > baseRise * 1.08,
           "TEST5 structures did not gain vertical screen authority")

    fake:drawLowPrism(proj, { x = 4, y = 5 }, 0.18)
    local rockHeightA = assert(fake._boundaryHeight, "boundary relief height missing")
    local rockWidthA = assert(fake._boundaryWidth, "boundary perspective width missing")
    local rockRiseA = assert(fake._boundaryRise, "boundary screen rise missing")
    assert(rockHeightA >= 0.23,
           "rock boundary remained too flat after live polish")
    local _, rb0 = proj:cell(4.5, 5.5, 0)
    local _, rb1 = proj:cell(4.5, 5.5, rockHeightA)
    local baseRockRise = math.abs(rb1 - rb0)
    assert(rockRiseA > baseRockRise * 1.25,
           "TEST5 rock boundary did not gain vertical screen authority")

    fake:drawLowPrism(proj, { x = 5, y = 5 }, 0.18)
    local rockHeightB = assert(fake._boundaryHeight, "second boundary relief height missing")
    assert(math.abs(rockHeightA - rockHeightB) > 0.001,
           "rock boundary relief has no deterministic height variation")
    fake:drawLowPrism(proj, { x = 4, y = 0 }, 0.18)
    local farRockWidth = assert(fake._boundaryWidth, "far boundary width missing")
    assert(rockWidthA > farRockWidth * 1.05,
           "rock boundaries are not shrinking with perspective depth")

    local canvas = love.graphics.newCanvas(960, 540)
    love.graphics.setCanvas(canvas)
    fake:drawBackdrop(ctx, proj)
    love.graphics.setCanvas()
    assert((fake.lastApronCells or 0) > 100,
           "outdoor non-playable terrain apron was not generated")
    assert((fake.lastInteriorShellPanels or 0) == 0,
           "outdoor scene incorrectly received interior shell")

    local roomMap = {
      def = { tileset = "REDSHOUSE1" },
      widthCells = 6,
      heightCells = 6,
    }
    local roomCtx = {
      width = 960, height = 540, vw = 160, vh = 144,
      cam = { x = 0, y = 0 }, bgY = 0,
      state = { map = roomMap, player = { px = 48, py = 48 } },
      paletteFor = ctx.paletteFor,
    }
    local roomProj = Projection.new(roomCtx, 2)
    love.graphics.setCanvas(canvas)
    fake:drawBackdrop(roomCtx, roomProj)
    love.graphics.setCanvas()
    assert((fake.lastInteriorShellPanels or 0) == 4,
           "room-like interior did not render the TEST5 dollhouse shell")
  end)

  if not ok then return fail(err) end
  print("PASS love_hd2d_live_polish_gate")
  love.event.quit(0)
end
