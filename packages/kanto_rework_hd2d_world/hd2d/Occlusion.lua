local Occlusion = {}
Occlusion.__index = Occlusion

local CELL = 16
local BOTTOM = 8

local function release(obj)
  if obj and obj.release then pcall(obj.release, obj) end
end

local function grassAt(map, cx, cy)
  if not map or type(map.isGrassCell) ~= "function" then return false end
  if type(cx) ~= "number" or type(cy) ~= "number" then return false end
  local ok, value = pcall(map.isGrassCell, map, cx, cy)
  return ok and value == true
end

function Occlusion.new()
  return setmetatable({
    grassCanvas = nil,
    overlays = 0,
  }, Occlusion)
end

function Occlusion:invalidate()
  release(self.grassCanvas)
  self.grassCanvas = nil
  self.overlays = 0
end

function Occlusion:ensureCanvas()
  if self.grassCanvas then return self.grassCanvas end
  if not (love and love.graphics and love.graphics.newCanvas) then return nil end
  local canvas = love.graphics.newCanvas(CELL, BOTTOM)
  if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
  self.grassCanvas = canvas
  return canvas
end

function Occlusion:captureBottom(map, cx, cy)
  local renderer = map and map.renderer
  if not (renderer and type(renderer.drawCellBottom) == "function") then
    return nil
  end
  local canvas = self:ensureCanvas()
  if not canvas then return nil end

  local previous = love.graphics.getCanvas and love.graphics.getCanvas() or nil
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)

  -- drawCellBottom paints the two 8x8 tiles that form the lower half of one
  -- walk cell. Choosing this camera origin lands those tiles at (0,0) and
  -- preserves the engine's own color-0 transparency / RED++ keyed path.
  renderer:drawCellBottom(cx, cy, cx * CELL, cy * CELL + BOTTOM)

  love.graphics.setCanvas(previous)
  love.graphics.pop()
  return canvas
end

function Occlusion:drawOne(map, proj, actor, cx, cy, ox, oy)
  if not grassAt(map, cx, cy) then return false end
  local canvas = self:captureBottom(map, cx, cy)
  if not canvas then return false end

  local px = tonumber(actor.px) or cx * CELL
  local py = tonumber(actor.py) or cy * CELL
  local wx = px + (ox or 0) + CELL * 0.5
  local wy = py + (oy or 0) + CELL
  local sx, sy = proj:projectWorld(wx, wy, 0)
  local scale = proj.scale or 1

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, sx - CELL * scale * 0.5,
                     sy - BOTTOM * scale, 0, scale, scale)
  self.overlays = self.overlays + 1
  return true
end

function Occlusion:draw(ctx, proj)
  local state = ctx and ctx.state
  local map = state and state.map
  if not (map and proj) then return 0 end

  self.overlays = 0
  for _, actor in ipairs(state.entities or {}) do
    if not ((state.flyAnim or state.flyArrive or state.playerHidden)
            and actor == state.player) then
      self:drawOne(map, proj, actor, actor.cellX, actor.cellY)
      if actor.targetX ~= nil and actor.targetY ~= nil then
        -- Gen1Recomp's flat and TILT paths redraw both current and target
        -- grass during a step. Keep the overlay glued to the actor's foot,
        -- matching that priority rule rather than moving it to the target cell.
        self:drawOne(map, proj, actor, actor.targetX, actor.targetY)
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
  return self.overlays
end

return Occlusion
