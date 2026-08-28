local NaturalForms = {}

local CELL = 16

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function sourceRect(renderer, x, y)
  local sx = x * CELL - (renderer.sourceCamX or 0)
  local sy = y * CELL - (renderer.sourceCamY or 0)
  if sx < 0 or sy < 0
     or sx + CELL > (renderer.sourceW or 0)
     or sy + CELL > (renderer.sourceH or 0) then
    return nil
  end
  return { sx, sy, CELL, CELL }
end

local CARD_SHAPE = {
  { -0.28, -0.50 }, { 0.28, -0.50 },
  { 0.50, -0.27 }, { 0.50, 0.27 },
  { 0.30, 0.50 }, { -0.30, 0.50 },
  { -0.50, 0.27 }, { -0.50, -0.27 },
}

local function ensureMesh(renderer)
  if renderer.naturalFormMesh then return renderer.naturalFormMesh end
  if not (love and love.graphics and love.graphics.newMesh) then return nil end
  local seed = {}
  for i = 1, #CARD_SHAPE do
    seed[i] = { 0, 0, 0, 0, 1, 1, 1, 1 }
  end
  local ok, mesh = pcall(love.graphics.newMesh, seed, "fan", "dynamic")
  if not ok or not mesh then return nil end
  renderer.naturalFormMesh = mesh
  return mesh
end

local function cardVertices(proj, x, y, height, width)
  local cx, cy = x + 0.5, y + 0.60
  local bx, by = proj:cell(cx, cy, 0.008)
  local tx, ty = proj:cell(cx, cy, height)
  local scale = proj.screenScale and proj:screenScale(cx, cy, 0)
                or proj.tileW or 1
  local half = scale * width * 0.5
  local out = {}
  for i, p in ipairs(CARD_SHAPE) do
    local nx, ny = p[1], p[2]
    local t = ny + 0.5
    local centerX = tx + (bx - tx) * t
    local centerY = ty + (by - ty) * t
    local localHalf = half * (0.92 + 0.08 * t)
    out[i] = {
      centerX + nx * 2 * localHalf,
      centerY,
      nx + 0.5,
      ny + 0.5,
    }
  end
  return out, bx, by, scale
end

local function drawTexturedCard(renderer, proj, cmd, height, width, tint)
  local rect = sourceRect(renderer, cmd.x, cmd.y)
  local mesh = rect and ensureMesh(renderer) or nil
  if not (mesh and mesh.setVertices and mesh.setTexture and renderer.source) then
    return false
  end

  local points, bx, by, scale = cardVertices(proj, cmd.x, cmd.y, height, width)
  local sx, sy, sw, sh = rect[1], rect[2], rect[3], rect[4]
  local vertices = {}
  for i, p in ipairs(points) do
    vertices[i] = {
      p[1], p[2],
      (sx + p[3] * sw) / renderer.sourceW,
      (sy + p[4] * sh) / renderer.sourceH,
      1, 1, 1, 1,
    }
  end

  local ok = pcall(function()
    mesh:setVertices(vertices)
    mesh:setTexture(renderer.source)
  end)
  if not ok then return false end

  love.graphics.setColor(0, 0, 0, 0.14)
  love.graphics.ellipse("fill", bx, by + 1,
                        scale * width * 0.34,
                        scale * width * 0.105)
  local c = tint or { 1, 1, 1 }
  love.graphics.setColor(clamp(c[1], 0, 1),
                         clamp(c[2], 0, 1),
                         clamp(c[3], 0, 1), 1)
  love.graphics.draw(mesh)
  return true
end

local function variation(cmd)
  local x = math.floor(tonumber(cmd and cmd.x) or 0)
  local y = math.floor(tonumber(cmd and cmd.y) or 0)
  return ((x * 17 + y * 29) % 5) / 4
end

function NaturalForms.apply(renderer)
  if not renderer or renderer.__naturalFormsApplied then return renderer end
  renderer.__naturalFormsApplied = true

  local baseResetMetrics = renderer.resetMetrics
  renderer.resetMetrics = function(self)
    baseResetMetrics(self)
    self.lastNaturalVegetationCards = 0
    self.lastNaturalBoundaryCards = 0
    self.lastNaturalCardFallbacks = 0
  end

  local baseInvalidate = renderer.invalidate
  renderer.invalidate = function(self)
    if self.naturalFormMesh and self.naturalFormMesh.release then
      pcall(self.naturalFormMesh.release, self.naturalFormMesh)
    end
    self.naturalFormMesh = nil
    return baseInvalidate(self)
  end

  local baseDrawVegetation = renderer.drawVegetation
  renderer.drawVegetation = function(self, proj, cmd)
    local v = variation(cmd)
    local level = tonumber(proj.level) or 2
    local baseH = ({ 0.88, 1.08, 1.24 })[level] or 1.08
    local height = baseH * (0.94 + v * 0.10)
    local width = 0.88 + v * 0.07
    if drawTexturedCard(self, proj, cmd, height, width,
                        { 0.98, 1.00, 0.96 }) then
      self.lastNaturalVegetationCards =
        (self.lastNaturalVegetationCards or 0) + 1
      return true
    end
    self.lastNaturalCardFallbacks = (self.lastNaturalCardFallbacks or 0) + 1
    return baseDrawVegetation(self, proj, cmd)
  end

  local baseDrawLowPrism = renderer.drawLowPrism
  renderer.drawLowPrism = function(self, proj, cmd, height, topColor)
    -- SceneRenderer passes >=0.17 only for continuous boundary families.
    -- Obstacles remain shallow prisms; boundaries become discrete textured
    -- upright forms so a long Route 1 edge cannot become one grey retaining wall.
    if (tonumber(height) or 0) >= 0.17 then
      local v = variation(cmd)
      local level = tonumber(proj.level) or 2
      local baseH = ({ 0.38, 0.50, 0.60 })[level] or 0.50
      local cardH = baseH * (0.90 + v * 0.16)
      local cardW = 0.74 + v * 0.09
      if drawTexturedCard(self, proj, cmd, cardH, cardW,
                          { 0.95, 0.97, 0.94 }) then
        self.lastNaturalBoundaryCards =
          (self.lastNaturalBoundaryCards or 0) + 1
        return true
      end
      self.lastNaturalCardFallbacks = (self.lastNaturalCardFallbacks or 0) + 1
    end
    return baseDrawLowPrism(self, proj, cmd, height, topColor)
  end

  return renderer
end

return NaturalForms
