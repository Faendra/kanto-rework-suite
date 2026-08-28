local Relief = {}
Relief.__index = Relief

local CELL = 16
local MARGIN_CELLS = 2

function Relief.new(MaterialClassifier)
  return setmetatable({
    MaterialClassifier = MaterialClassifier,
    lastScenes = 0,
    lastCells = 0,
  }, Relief)
end

local function visibleCellRange(map, proj, ox, oy)
  ox, oy = ox or 0, oy or 0
  local localLeft = proj.camX - ox
  local localTop = proj.bgY - oy
  local x0 = math.floor(localLeft / CELL) - MARGIN_CELLS
  local y0 = math.floor(localTop / CELL) - MARGIN_CELLS
  local x1 = math.ceil((localLeft + proj.vw) / CELL) + MARGIN_CELLS
  local y1 = math.ceil((localTop + proj.vh) / CELL) + MARGIN_CELLS
  x0 = math.max(0, x0)
  y0 = math.max(0, y0)
  x1 = math.min((map.widthCells or 0) - 1, x1)
  y1 = math.min((map.heightCells or 0) - 1, y1)
  return x0, y0, x1, y1
end

function Relief:drawScene(host, ctx, proj, map, ox, oy)
  if not (host and host.source and host.cellQuad and map) then return 0 end
  if not (map.widthCells and map.heightCells) then return 0 end

  ox, oy = ox or 0, oy or 0
  local x0, y0, x1, y1 = visibleCellRange(map, proj, ox, oy)
  if x1 < x0 or y1 < y0 then return 0 end

  local classifier = self.MaterialClassifier
  local lift = proj.relief
  local wallR, wallG, wallB, wallA = host:paletteWallColor(ctx, map, 0.90, 0.66)
  local sideR, sideG, sideB, sideA = host:paletteWallColor(ctx, map, 0.82, 0.54)
  local drawn = 0

  for cy = y0, y1 do
    for cx = x0, x1 do
      local material = classifier.classify(map, cx, cy)
      if material.kind == "solid" then
        local height = classifier.reliefHeight(material, lift)
        local wx, wy = cx * CELL + ox, cy * CELL + oy

        if classifier.frontExposed(map, cx, cy) then
          local ax, ay = proj:projectTerrain(wx, wy + CELL, 0)
          local bx, by = proj:projectTerrain(wx + CELL, wy + CELL, 0)
          local tax, tay = proj:projectTerrain(wx, wy + CELL, height)
          local tbx, tby = proj:projectTerrain(wx + CELL, wy + CELL, height)
          love.graphics.setColor(wallR, wallG, wallB, wallA)
          love.graphics.polygon("fill", tax, tay, tbx, tby, bx, by, ax, ay)
        end

        if classifier.sideExposed(map, cx, cy, 1) then
          local ax, ay = proj:projectTerrain(wx + CELL, wy, 0)
          local bx, by = proj:projectTerrain(wx + CELL, wy + CELL, 0)
          local tax, tay = proj:projectTerrain(wx + CELL, wy, height)
          local tbx, tby = proj:projectTerrain(wx + CELL, wy + CELL, height)
          love.graphics.setColor(sideR, sideG, sideB, sideA)
          love.graphics.polygon("fill", tax, tay, tbx, tby, bx, by, ax, ay)
        end

        -- Source capture already contains the correctly offset neighbour map.
        -- Re-sample its visible top using world-space offset, so the active map
        -- and connected map share one relief rule right through the seam.
        local sx = wx - proj.camX
        local sy = wy - proj.bgY
        if sx >= 0 and sy >= 0
           and sx + CELL <= host.sourceW and sy + CELL <= host.sourceH then
          host.cellQuad:setViewport(sx, sy, CELL, CELL, host.sourceW, host.sourceH)
          local metrics = proj:cellMetrics(wx, wy, CELL, height)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(host.source, host.cellQuad, metrics.x, metrics.y,
                             0, metrics.width / CELL, metrics.height / CELL)
        end
        drawn = drawn + 1
      end
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
  return drawn
end

function Relief:draw(host, ctx, proj)
  local state = ctx and ctx.state
  local map = state and state.map
  if not map then return 0 end

  self.lastScenes, self.lastCells = 0, 0
  self.lastScenes = self.lastScenes + 1
  self.lastCells = self.lastCells + self:drawScene(host, ctx, proj, map, 0, 0)

  for _, nb in ipairs(state.neighbors or {}) do
    if nb.map then
      self.lastScenes = self.lastScenes + 1
      self.lastCells = self.lastCells
        + self:drawScene(host, ctx, proj, nb.map, nb.ox or 0, nb.oy or 0)
    end
  end
  return self.lastCells
end

return Relief
