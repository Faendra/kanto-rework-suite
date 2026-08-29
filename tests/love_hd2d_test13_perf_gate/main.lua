local function fail(message)
  io.stderr:write("FAIL love_hd2d_test13_perf_gate: " .. tostring(message) .. "\n")
  love.event.quit(1)
end

local function module(root, rel)
  local ok, result = pcall(dofile, root .. "/packages/kanto_rework_hd2d_world/" .. rel)
  if not ok then error(result, 0) end
  return result
end

function love.load()
  love.filesystem.setIdentity("krs-hd2d-test13-perf-gate")
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local VanillaMotifs = module(root, "hd2d/VanillaMotifs.lua")
    package.preload["hd2d.VanillaMotifs"] = function() return VanillaMotifs end
    local NaturalForms = module(root, "hd2d/NaturalForms.lua")

    -- One shared 16x16 atlas cell, equivalent to AtlasSource.cellTexture's
    -- motif cache: a whole row of identical vanilla trees reuses this Canvas.
    local source = love.graphics.newCanvas(16, 16)
    love.graphics.setCanvas(source)
    love.graphics.clear(0.84, 0.91, 0.68, 1)
    love.graphics.setColor(0.08, 0.28, 0.10, 1)
    love.graphics.rectangle("fill", 2, 3, 12, 12)
    love.graphics.setColor(0.34, 0.65, 0.21, 1)
    love.graphics.rectangle("fill", 4, 2, 8, 8)
    love.graphics.setCanvas()
    source:setFilter("nearest", "nearest")

    local fallback = 0
    local renderer = {
      source = source, sourceW = 16, sourceH = 16,
      sourceCamX = 0, sourceCamY = 0,
      resetMetrics = function() end,
      invalidate = function() end,
      drawVegetation = function() fallback = fallback + 1 return true end,
      drawLowPrism = function() return true end,
    }
    NaturalForms.apply(renderer)
    renderer:resetMetrics()

    local proj = {
      level = 2, tileW = 32,
      cell = function(_, x, y, z) return x * 32, y * 16 - (z or 0) * 24 end,
      screenScale = function() return 32 end,
    }

    local output = love.graphics.newCanvas(1024, 256)
    love.graphics.setCanvas(output)
    love.graphics.clear(0.55, 0.72, 0.82, 1)
    for i = 0, 31 do
      local cmd = { x = i, y = 4 }
      -- AtlasWorld.withTexture does exactly this for each world cell while the
      -- shared source Canvas remains identical for an identical tile quartet.
      renderer.sourceCamX = cmd.x * 16
      renderer.sourceCamY = cmd.y * 16
      renderer:drawVegetation(proj, cmd)
    end
    love.graphics.setCanvas()

    assert(fallback == 0, "tree silhouette path unexpectedly fell back")
    assert((renderer.lastNaturalSilhouetteBillboards or 0) == 32,
           "not all repeated trees used silhouette billboards")
    assert((renderer.lastNaturalSilhouetteReadbacks or 0) == 1,
           "repeated tree motif caused more than one GPU ImageData readback")
    assert((renderer.lastNaturalSilhouetteCacheHits or 0) == 31,
           "repeated tree motif did not reuse cached silhouette")

    source:release()
    output:release()
  end)

  package.preload["hd2d.VanillaMotifs"] = nil
  if not ok then return fail(err) end
  print("PASS love_hd2d_test13_perf_gate")
  love.event.quit(0)
end
