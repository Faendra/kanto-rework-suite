local WaterSurface = {}
WaterSurface.__index = WaterSurface

local CELL = 16
local MARGIN_CELLS = 2

function WaterSurface.new(MaterialClassifier)
  return setmetatable({
    MaterialClassifier = MaterialClassifier,
    lastScenes = 0,
    lastCells = 0,
    lastRuns = 0,
    lastBanks = 0,
  }, WaterSurface)
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

local function isWater(classifier, map, cx, cy)
  return classifier.classify(map, cx, cy).kind == "water"
end

function WaterSurface.recessForLevel(level)
  level = tonumber(level) or 1
  if level >= 3 then return 2.5 end
  if level >= 2 then return 1.8 end
  return 1.25
end

function WaterSurface.surfaceZ(level)
  return -WaterSurface.recessForLevel(level)
end

local function projectedRect(proj, wx, wy, worldW, worldH, z)
  local localY = wy - proj.bgY + worldH * 0.5
  local depth = proj:depthScale(localY)
  local cx, cy = proj:projectTerrain(wx + worldW * 0.5,
                                     wy + worldH * 0.5, z)
  local sw = worldW * depth * proj.scale
  local sh = worldH * proj.compression * proj.scale
  return cx - sw * 0.5, cy - sh * 0.5, sw, sh
end

local function drawMask(host, ctx, proj, map, wx, wy, worldW)
  local x0, y0 = proj:projectTerrain(wx, wy, 0)
  local x1, y1 = proj:projectTerrain(wx + worldW, wy, 0)
  local x2, y2 = proj:projectTerrain(wx + worldW, wy + CELL, 0)
  local x3, y3 = proj:projectTerrain(wx, wy + CELL, 0)
  local r, g, b, a = host:paletteWallColor(ctx, map, 1, 0.78)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", x0, y0, x1, y1, x2, y2, x3, y3)
end

local function drawLowerTexture(host, proj, wx, wy, cells, recess)
  local runW = cells * CELL
  local sx = wx - proj.camX
  local sy = wy - proj.bgY
  if sx < 0 or sy < 0 or sx + runW > host.sourceW or sy + CELL > host.sourceH then
    return false
  end

  host.cellQuad:setViewport(sx, sy, runW, CELL, host.sourceW, host.sourceH)
  local x, y, sw, sh = projectedRect(proj, wx, wy, runW, CELL, -recess)
  love.graphics.setColor(1, 1, 1, 0.96)
  love.graphics.draw(host.source, host.cellQuad, x, y, 0, sw / runW, sh / CELL)
  return true
end

local function drawBank(host, ctx, proj, map, wx0, wx1, wy, recess)
  local ax, ay = proj:projectTerrain(wx0, wy, 0)
  local bx, by = proj:projectTerrain(wx1, wy, 0)
  local lax, lay = proj:projectTerrain(wx0, wy, -recess)
  local lbx, lby = proj:projectTerrain(wx1, wy, -recess)
  local r, g, b, a = host:paletteWallColor(ctx, map, 0.96, 0.58)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", ax, ay, bx, by, lbx, lby, lax, lay)
end

function WaterSurface:drawScene(host, ctx, proj, map, ox, oy, level)
  if not (host and host.source and host.cellQuad and map) then return 0 end
  if not (map.widthCells and map.heightCells) then return 0 end

  ox, oy = ox or 0, oy or 0
  local x0, y0, x1, y1 = visibleCellRange(map, proj, ox, oy)
  if x1 < x0 or y1 < y0 then return 0 end

  local classifier = self.MaterialClassifier
  local recess = WaterSurface.recessForLevel(level or 1)
  local cells = 0

  for cy = y0, y1 do
    local cx = x0
    while cx <= x1 do
      if isWater(classifier, map, cx, cy) then
        local startX, endX = cx, cx
        while endX + 1 <= x1 and isWater(classifier, map, endX + 1, cy) do
          endX = endX + 1
        end

        local count = endX - startX + 1
        local wx = startX * CELL + ox
        local wy = cy * CELL + oy
        local worldW = count * CELL
        cells = cells + count

        -- Erase the flat source-water footprint with a palette-derived base,
        -- then re-sample the same animated/current terrain slightly below the
        -- land plane. This creates depth without inventing a second water art
        -- source or changing collision semantics.
        drawMask(host, ctx, proj, map, wx, wy, worldW)

        -- Only expose a front bank where the water body ends toward the
        -- camera. Contiguous water rows remain one lower plane instead of a
        -- stack of per-row troughs.
        local bankStart = nil
        for bx = startX, endX do
          local exposed = not isWater(classifier, map, bx, cy + 1)
          if exposed and not bankStart then bankStart = bx end
          if bankStart and (not exposed or bx == endX) then
            local bankEnd = exposed and bx or (bx - 1)
            drawBank(host, ctx, proj, map,
                     bankStart * CELL + ox, (bankEnd + 1) * CELL + ox,
                     (cy + 1) * CELL + oy, recess)
            self.lastBanks = self.lastBanks + 1
            bankStart = nil
          end
        end

        if drawLowerTexture(host, proj, wx, wy, count, recess) then
          self.lastRuns = self.lastRuns + 1
        end
        cx = endX + 1
      else
        cx = cx + 1
      end
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
  return cells
end

function WaterSurface:draw(host, ctx, proj, level)
  local state = ctx and ctx.state
  local map = state and state.map
  if not map then return 0 end

  self.lastScenes, self.lastCells = 0, 0
  self.lastRuns, self.lastBanks = 0, 0
  self.lastScenes = self.lastScenes + 1
  self.lastCells = self.lastCells
    + self:drawScene(host, ctx, proj, map, 0, 0, level)

  for _, nb in ipairs(state.neighbors or {}) do
    if nb.map then
      self.lastScenes = self.lastScenes + 1
      self.lastCells = self.lastCells
        + self:drawScene(host, ctx, proj, nb.map, nb.ox or 0, nb.oy or 0, level)
    end
  end
  return self.lastCells
end

return WaterSurface
