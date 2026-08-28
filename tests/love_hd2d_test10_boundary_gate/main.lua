local function fail(message)
  io.stderr:write("FAIL love_hd2d_test10_boundary_gate: " .. tostring(message) .. "\n")
  love.event.quit(1)
end

local function module(root, rel)
  local ok, result = pcall(dofile, root .. "/packages/kanto_rework_hd2d_world/" .. rel)
  if not ok then error(result, 0) end
  return result
end

local function mapWithQuartet(quartet)
  local map = { def = { tileset = "OVERWORLD" } }
  function map:tileAt(tx, ty)
    local qi = (ty % 2) * 2 + (tx % 2) + 1
    return quartet[qi]
  end
  return map
end

function love.load()
  love.filesystem.setIdentity("krs-hd2d-test10-boundary-gate")
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local VanillaMotifs = module(root, "hd2d/VanillaMotifs.lua")
    package.preload["hd2d.VanillaMotifs"] = function() return VanillaMotifs end
    local NaturalScale = module(root, "hd2d/NaturalScale.lua")

    local basePrisms = 0
    local decals = 0
    local renderer = {
      resetMetrics = function() end,
      drawVegetation = function() return true end,
      drawLowPrism = function()
        basePrisms = basePrisms + 1
        return true
      end,
      drawTexturedQuad = function(_, _, _, _, z, rect)
        assert(math.abs((z or 0) - 0.006) < 0.0001,
          "generic boundary decal was not grounded")
        assert(rect and rect.atlasImage,
          "generic boundary decal did not use runtime atlas texture")
        decals = decals + 1
        return true
      end,
    }
    renderer = NaturalScale.apply(renderer)
    renderer:resetMetrics()

    local unknownMap = mapWithQuartet({ 0x22, 0x22, 0x22, 0x22 })
    assert(VanillaMotifs.cellMotif(unknownMap, 0, 0) == nil,
      "unknown boundary quartet unexpectedly matched a canonical motif")
    local tex = love.graphics.newCanvas(16, 16)
    local cmd = {
      kind = "boundary", x = 0, y = 0,
      scene = { map = unknownMap, ox = 0, oy = 0 },
      atlasTexture = tex,
    }
    local proj = { level = 2 }
    renderer:drawLowPrism(proj, cmd, 0.18, { 0.58, 0.61, 0.56 })

    assert(decals == 1,
      "generic outdoor boundary was not converted to a flat atlas decal")
    assert(basePrisms == 0,
      "generic outdoor boundary still reached grey prism renderer")
    assert((renderer.lastGroundedGenericBoundaries or 0) == 1,
      "grounded generic-boundary metric missing")

    -- Canonical boulders must remain real low 3D forms, not be flattened away.
    local boulderMap = mapWithQuartet(VanillaMotifs.BOULDER)
    local boulderCmd = {
      kind = "boundary", x = 0, y = 0,
      scene = { map = boulderMap, ox = 0, oy = 0 },
      atlasTexture = tex,
    }
    renderer:drawLowPrism(proj, boulderCmd, 0.18, { 0.58, 0.61, 0.56 })
    assert(basePrisms == 1,
      "canonical boulder no longer reaches its 3D form path")
    assert((renderer.lastFlattenedBoulders or 0) == 1,
      "canonical boulder scale tuning missing")

    tex:release()
  end)

  package.preload["hd2d.VanillaMotifs"] = nil
  if not ok then return fail(err) end
  print("PASS love_hd2d_test10_boundary_gate")
  love.event.quit(0)
end
