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
        return true
      end,
      drawStructure = function() return true end,
    }
    LivePolish.apply(fake)

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
    fake:drawVegetation(proj, { x = 4, y = 0 })
    local farTree = assert(fake._vegetationWidth, "far vegetation width missing")
    assert(nearTree > farTree * 1.05,
           "vegetation silhouettes are not shrinking with perspective depth")

    love.graphics.setCanvas(love.graphics.newCanvas(960, 540))
    fake:drawBackdrop(ctx, proj)
    love.graphics.setCanvas()
    assert((fake.lastApronCells or 0) > 100,
           "outdoor non-playable terrain apron was not generated")
  end)

  if not ok then return fail(err) end
  print("PASS love_hd2d_live_polish_gate")
  love.event.quit(0)
end
