local DioramaPolish = {}

local ROOM_TILESETS = {
  REDSHOUSE1 = true,
  MART = true,
  REDSHOUSE2 = true,
  DOJO = true,
  POKECENTER = true,
  GYM = true,
  HOUSE = true,
  FORESTGATE = true,
  MUSEUM = true,
  GATE = true,
  SHIP = true,
  CEMETERY = true,
  INTERIOR = true,
  LOBBY = true,
  MANSION = true,
  LAB = true,
  CLUB = true,
  FACILITY = true,
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function mapTileset(map)
  return map and map.def and map.def.tileset or nil
end

local function drawPoly(points)
  love.graphics.polygon("fill", points)
end

local function southWall(proj, x0, x1, y, z0, z1)
  local ax, ay = proj:cell(x0, y, z0)
  local bx, by = proj:cell(x1, y, z0)
  local cx, cy = proj:cell(x1, y, z1)
  local dx, dy = proj:cell(x0, y, z1)
  return { ax, ay, bx, by, cx, cy, dx, dy }
end

local function eastWall(proj, x, y0, y1, z0, z1)
  local ax, ay = proj:cell(x, y0, z0)
  local bx, by = proj:cell(x, y1, z0)
  local cx, cy = proj:cell(x, y1, z1)
  local dx, dy = proj:cell(x, y0, z1)
  return { ax, ay, bx, by, cx, cy, dx, dy }
end

-- Existing scene object drawers are retained; only their visual Z is magnified.
-- Gameplay coordinates, painter depth and collision remain the original values.
local function verticalProxy(proj, zFactor, widthFactor)
  zFactor = tonumber(zFactor) or 1
  widthFactor = tonumber(widthFactor) or 1
  local proxy = {
    tileW = (proj.tileW or 1) * widthFactor,
    tileH = proj.tileH,
    elevation = proj.elevation,
    spriteScale = proj.spriteScale,
  }

  proxy.cell = function(_, x, y, z)
    return proj:cell(x, y, (z or 0) * zFactor)
  end
  proxy.worldPixel = function(_, wx, wy, z)
    return proj:worldPixel(wx, wy, (z or 0) * zFactor)
  end
  proxy.quad = function(_, x0, y0, x1, y1, z)
    return proj:quad(x0, y0, x1, y1, (z or 0) * zFactor)
  end
  proxy.cellPolygon = function(_, x, y, z)
    return proj:cellPolygon(x, y, (z or 0) * zFactor)
  end
  proxy.screenScale = function(_, x, y, z)
    return proj:screenScale(x, y, (z or 0) * zFactor)
  end
  proxy.spriteScaleAt = function(_, x, y, z)
    return proj:spriteScaleAt(x, y, (z or 0) * zFactor)
  end
  proxy.depth = function(_, x, y, bias)
    return proj:depth(x, y, bias)
  end
  proxy.visibleRadius = function()
    return proj:visibleRadius()
  end

  return setmetatable(proxy, { __index = proj })
end

local function colorFromPalette(ctx, map)
  local wall = { 0.58, 0.56, 0.49 }
  local side = { 0.38, 0.39, 0.37 }
  local trim = { 0.78, 0.72, 0.57 }
  local palette = ctx and ctx.paletteFor and ctx.paletteFor(map) or nil
  local p2 = type(palette) == "table" and palette[2] or nil
  local p3 = type(palette) == "table" and palette[3] or nil
  if type(p2) == "table" then
    local r, g, b = tonumber(p2[1]), tonumber(p2[2]), tonumber(p2[3])
    if r and g and b then
      if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
      wall = {
        clamp(wall[1] * 0.60 + r * 0.40, 0, 1),
        clamp(wall[2] * 0.60 + g * 0.40, 0, 1),
        clamp(wall[3] * 0.60 + b * 0.40, 0, 1),
      }
    end
  end
  if type(p3) == "table" then
    local r, g, b = tonumber(p3[1]), tonumber(p3[2]), tonumber(p3[3])
    if r and g and b then
      if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
      side = {
        clamp(side[1] * 0.58 + r * 0.42, 0, 1),
        clamp(side[2] * 0.58 + g * 0.42, 0, 1),
        clamp(side[3] * 0.58 + b * 0.42, 0, 1),
      }
    end
  end
  return wall, side, trim
end

local function drawInteriorShell(renderer, ctx, proj)
  local map = ctx and ctx.state and ctx.state.map
  if not map or not ROOM_TILESETS[mapTileset(map)] then return 0 end
  local w = tonumber(map.widthCells) or 0
  local h = tonumber(map.heightCells) or 0
  if w <= 0 or h <= 0 then return 0 end

  local wallColor, sideColor, trimColor = colorFromPalette(ctx, map)
  local wallH = ({ 0.78, 0.92, 1.04 })[proj.level] or 0.92
  local slab = 0.105

  -- Pick the two genuinely far edges from the current projection so the shell
  -- stays a camera-facing dollhouse rather than hiding the playable room.
  local _, westY = proj:cell(0, h * 0.5, 0)
  local _, eastY = proj:cell(w, h * 0.5, 0)
  local farX = westY < eastY and 0 or w
  local nearX = farX == 0 and w or 0

  local _, northY = proj:cell(w * 0.5, 0, 0)
  local _, southY = proj:cell(w * 0.5, h, 0)
  local farY = northY < southY and 0 or h
  local nearY = farY == 0 and h or 0

  love.graphics.push("all")

  -- A soft footprint under the whole room makes the interior read as a physical
  -- miniature instead of a flat card suspended in an infinite black field.
  love.graphics.setColor(0, 0, 0, 0.28)
  drawPoly(proj:quad(-0.10, -0.08, w + 0.18, h + 0.18, -slab - 0.035))

  love.graphics.setColor(sideColor[1], sideColor[2], sideColor[3], 1)
  drawPoly(southWall(proj, 0, w, nearY, -slab, -0.002))
  drawPoly(eastWall(proj, nearX, 0, h, -slab, -0.002))

  -- Far walls only. Near edges remain open for visibility and movement.
  love.graphics.setColor(wallColor[1], wallColor[2], wallColor[3], 1)
  drawPoly(southWall(proj, 0, w, farY, 0, wallH))
  love.graphics.setColor(sideColor[1], sideColor[2], sideColor[3], 1)
  drawPoly(eastWall(proj, farX, 0, h, 0, wallH * 0.94))

  if love.graphics.line and love.graphics.setLineWidth then
    love.graphics.setLineWidth(math.max(1, (proj.tileW or 1) * 0.018))
    love.graphics.setColor(trimColor[1], trimColor[2], trimColor[3], 0.82)
    local ax, ay = proj:cell(0, farY, wallH)
    local bx, by = proj:cell(w, farY, wallH)
    love.graphics.line(ax, ay, bx, by)
    local cx, cy = proj:cell(farX, 0, wallH * 0.94)
    local dx, dy = proj:cell(farX, h, wallH * 0.94)
    love.graphics.line(cx, cy, dx, dy)
  end

  love.graphics.pop()
  return 4
end

function DioramaPolish.apply(renderer)
  if not renderer or renderer.__dioramaPolishApplied then return renderer end
  renderer.__dioramaPolishApplied = true

  local baseResetMetrics = renderer.resetMetrics
  renderer.resetMetrics = function(self)
    baseResetMetrics(self)
    self.lastInteriorShellPanels = 0
    self.lastVerticalizedStructures = 0
    self.lastVerticalizedVegetation = 0
    self.lastVerticalizedBoundaries = 0
  end

  local baseDrawBackdrop = renderer.drawBackdrop
  renderer.drawBackdrop = function(self, ctx, proj)
    baseDrawBackdrop(self, ctx, proj)
    self.lastInteriorShellPanels = drawInteriorShell(self, ctx, proj)
  end

  local baseDrawStructure = renderer.drawStructure
  renderer.drawStructure = function(self, proj, cmd)
    local factor = ({ 1.08, 1.15, 1.22 })[proj.level] or 1.15
    self.lastVerticalizedStructures = (self.lastVerticalizedStructures or 0) + 1
    return baseDrawStructure(self, verticalProxy(proj, factor, 1.02), cmd)
  end

  local baseDrawVegetation = renderer.drawVegetation
  renderer.drawVegetation = function(self, proj, cmd)
    local factor = ({ 1.42, 1.62, 1.80 })[proj.level] or 1.62
    local width = ({ 1.08, 1.16, 1.22 })[proj.level] or 1.16
    self.lastVerticalizedVegetation = (self.lastVerticalizedVegetation or 0) + 1
    return baseDrawVegetation(self, verticalProxy(proj, factor, width), cmd)
  end

  local baseDrawLowPrism = renderer.drawLowPrism
  renderer.drawLowPrism = function(self, proj, cmd, height, topColor)
    local boundary = (tonumber(height) or 0) >= 0.17
    local factor
    if boundary then
      factor = ({ 1.30, 1.55, 1.72 })[proj.level] or 1.55
      self.lastVerticalizedBoundaries = (self.lastVerticalizedBoundaries or 0) + 1
    else
      factor = ({ 1.08, 1.16, 1.24 })[proj.level] or 1.16
    end
    return baseDrawLowPrism(self, verticalProxy(proj, factor, 1.0),
                            cmd, height, topColor)
  end

  return renderer
end

DioramaPolish.ROOM_TILESETS = ROOM_TILESETS
DioramaPolish.verticalProxy = verticalProxy

return DioramaPolish
