local function fail(message)
  io.stderr:write("FAIL love_hd2d_style_gate: " .. tostring(message) .. "\n")
  love.event.quit(1)
end

local function module(root, rel)
  local ok, result = pcall(dofile, root .. "/packages/kanto_rework_hd2d_world/" .. rel)
  if not ok then error(result, 0) end
  return result
end

function love.load()
  love.filesystem.setIdentity("krs-hd2d-style-gate")
  local root = os.getenv("KRS_ROOT")
  if not root or root == "" then return fail("KRS_ROOT is required") end

  local ok, err = pcall(function()
    local SceneStyle = module(root, "hd2d/SceneStyle.lua")

    local classifier = {}
    function classifier.classify()
      return { kind = "solid", family = "vegetation" }
    end
    function classifier.massInfo()
      return { touchesEdge = false }
    end

    local source = love.graphics.newCanvas(16, 16)
    source:setFilter("nearest", "nearest")
    love.graphics.setCanvas(source)
    love.graphics.clear(0.10, 0.26, 0.12, 1)
    love.graphics.setColor(0.31, 0.59, 0.27, 1)
    love.graphics.rectangle("fill", 2, 2, 12, 7)
    love.graphics.setColor(0.48, 0.72, 0.34, 1)
    love.graphics.rectangle("fill", 5, 3, 6, 4)
    love.graphics.setCanvas()

    local mesh = love.graphics.newMesh({
      { 0, 0, 0, 0, 1, 1, 1, 1 },
      { 1, 0, 1, 0, 1, 1, 1, 1 },
      { 1, 1, 1, 1, 1, 1, 1, 1 },
      { 0, 1, 0, 1, 1, 1, 1, 1 },
    }, "fan", "dynamic")

    local renderer = {
      MaterialClassifier = classifier,
      source = source,
      sourceW = 16,
      sourceH = 16,
      sourceCamX = 0,
      sourceCamY = 0,
      mesh = mesh,
      resetMetrics = function(self)
        self.lastTexturedVegetation = 0
      end,
      invalidate = function() end,
    }
    SceneStyle.apply(renderer)
    renderer:resetMetrics()

    local proj = { level = 2, tileW = 64 }
    function proj:cell(x, y, z)
      return 160 + (x - y) * 32,
             150 + (x + y) * 13 - (z or 0) * 48
    end
    function proj:quad(x0, y0, x1, y1, z)
      local ax, ay = self:cell(x0, y0, z)
      local bx, by = self:cell(x1, y0, z)
      local cx, cy = self:cell(x1, y1, z)
      local dx, dy = self:cell(x0, y1, z)
      return { ax, ay, bx, by, cx, cy, dx, dy }
    end

    local target = love.graphics.newCanvas(320, 240)
    love.graphics.setCanvas(target)
    love.graphics.clear(0.65, 0.75, 0.68, 1)
    renderer:drawVegetation(proj, { x = 0, y = 0 })
    love.graphics.setCanvas()

    assert(renderer.lastTexturedVegetation == 1,
      "source pixel texture did not render through the vegetation crown mesh")
    assert(renderer.crownMesh ~= nil,
      "vegetation crown mesh was not allocated on real LÖVE")

    renderer:invalidate()
    mesh:release()
    source:release()
    target:release()
  end)

  if not ok then return fail(err) end
  print("PASS love_hd2d_style_gate")
  love.event.quit(0)
end
