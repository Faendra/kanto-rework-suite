local function fail(message)
  io.stderr:write("FAIL love_hd2d_shader_gate: " .. tostring(message) .. "\n")
  love.event.quit(1)
end

function love.load()
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local okLoad, Atmosphere = pcall(dofile,
    root .. "/packages/kanto_rework_hd2d_world/hd2d/WorldAtmosphere.lua")
  if not okLoad or type(Atmosphere) ~= "table" then
    return fail("cannot load WorldAtmosphere.lua: " .. tostring(Atmosphere))
  end

  local ok, err = pcall(function()
    local atmosphere = Atmosphere.new()
    assert(atmosphere:shaderAvailable(), "real LÖVE shader API unavailable")

    local source = love.graphics.newCanvas(320, 180)
    source:setFilter("nearest", "nearest")
    love.graphics.setCanvas(source)
    love.graphics.clear(0.12, 0.20, 0.28, 1)
    love.graphics.setCanvas()

    local out = atmosphere:present(source, {}, 2, 0.61)
    assert(out ~= nil and out ~= source,
      "world atmosphere did not produce a replacement canvas")
    assert(atmosphere.shader ~= nil,
      "WorldAtmosphere did not compile a real LÖVE shader")
    assert(atmosphere.shaderFailed == false,
      "WorldAtmosphere marked real shader compilation failed")
    assert(atmosphere.lastPasses == 1,
      "world atmosphere did not execute exactly one real GPU pass")
    assert(math.abs((atmosphere.lastFocusY or 0) - 0.61) < 0.0001,
      "requested focus band was not applied")
    assert(out:getWidth() == 320 and out:getHeight() == 180,
      "atmosphere output dimensions changed")

    local level1 = atmosphere:present(source, {}, 1, 0.57)
    assert(level1 ~= nil and atmosphere.lastPasses == 1,
      "HD2D level failed real shader presentation")

    atmosphere:invalidate()
  end)

  if not ok then return fail(err) end
  print("PASS love_hd2d_shader_gate")
  love.event.quit(0)
end
