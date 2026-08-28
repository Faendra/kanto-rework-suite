local VanillaMotifs = require("hd2d.VanillaMotifs")

local NaturalForms = {}

local CELL = 16
local BACKGROUND_LUMA = 0.44

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function safeRelease(obj)
  if obj and obj.release then pcall(obj.release, obj) end
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

local BOULDER_SHAPE = {
  { -0.23, -0.43 }, { 0.23, -0.43 },
  { 0.43, -0.23 }, { 0.43, 0.23 },
  { 0.23, 0.43 }, { -0.23, 0.43 },
  { -0.43, 0.23 }, { -0.43, -0.23 },
}

local function ensureMesh(renderer)
  if renderer.naturalFormMesh then return renderer.naturalFormMesh end
  if not (love and love.graphics and love.graphics.newMesh) then return nil end
  local seed = {}
  for i = 1, 8 do
    seed[i] = { 0, 0, 0, 0, 1, 1, 1, 1 }
  end
  local ok, mesh = pcall(love.graphics.newMesh, seed, "fan", "dynamic")
  if not ok or not mesh then return nil end
  renderer.naturalFormMesh = mesh
  return mesh
end

local function heightForScreen(proj, cx, cy, targetPixels, fallback)
  if not (proj and type(proj.cell) == "function") then return fallback end
  local _, baseY = proj:cell(cx, cy, 0.008)
  if type(baseY) ~= "number" then return fallback end

  local lo, hi = 0.04, 3.20
  for _ = 1, 11 do
    local mid = (lo + hi) * 0.5
    local _, topY = proj:cell(cx, cy, mid)
    if type(topY) ~= "number" then return fallback end
    local pixels = math.abs(baseY - topY)
    if pixels < targetPixels then lo = mid else hi = mid end
  end
  return (lo + hi) * 0.5
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

-- Legacy compatibility fallback. TEST8's nominal tree path below no longer
-- warps the 16x16 vanilla cell through this octagonal mesh.
local function drawTexturedCard(renderer, proj, cmd,
                                screenHeightRatio, width, tint, fallbackHeight)
  local rect = sourceRect(renderer, cmd.x, cmd.y)
  local mesh = rect and ensureMesh(renderer) or nil
  if not (mesh and mesh.setVertices and mesh.setTexture and renderer.source) then
    return false
  end

  local cx, cy = cmd.x + 0.5, cmd.y + 0.60
  local scale = proj.screenScale and proj:screenScale(cx, cy, 0)
                or proj.tileW or 1
  local targetPixels = math.max(2, scale * screenHeightRatio)
  local height = heightForScreen(proj, cx, cy, targetPixels,
                                 fallbackHeight or 0.6)
  local points, bx, by = cardVertices(proj, cmd.x, cmd.y, height, width)
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

  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.ellipse("fill", bx, by + 1,
                        scale * width * 0.35,
                        scale * width * 0.11)
  local c = tint or { 1, 1, 1 }
  love.graphics.setColor(clamp(c[1], 0, 1),
                         clamp(c[2], 0, 1),
                         clamp(c[3], 0, 1), 1)
  love.graphics.draw(mesh)
  return true
end

local function luminance(r, g, b)
  return (r + g + b) / 3
end

-- Build a one-time alpha mask from the exact 16x16 runtime atlas cell.
-- We intentionally do NOT clear every edge-connected pixel: the canonical Red
-- tree touches the cell border with dark foliage. Only bright background pixels
-- connected to the outer edge are removed, preserving disconnected highlights
-- and all dark silhouette pixels even when they meet the border.
local function silhouetteTexture(renderer)
  local source = renderer and renderer.source
  if not source then return nil, 0 end

  renderer.naturalSilhouetteCache = renderer.naturalSilhouetteCache or {}
  local cached = renderer.naturalSilhouetteCache[source]
  if cached then return cached.image, cached.cleared or 0 end

  if not (source.newImageData and love and love.graphics
          and love.graphics.newImage) then return nil, 0 end

  local ok, data = pcall(source.newImageData, source)
  if not ok or not data then return nil, 0 end
  local w, h = data:getDimensions()
  if w ~= CELL or h ~= CELL then
    safeRelease(data)
    return nil, 0
  end

  local visited = {}
  local qx, qy = {}, {}
  local head, tail = 1, 0
  local function index(x, y) return y * w + x + 1 end
  local function candidate(x, y)
    local r, g, b, a = data:getPixel(x, y)
    return a > 0.01 and luminance(r, g, b) >= BACKGROUND_LUMA
  end
  local function push(x, y)
    if x < 0 or y < 0 or x >= w or y >= h then return end
    local i = index(x, y)
    if visited[i] or not candidate(x, y) then return end
    visited[i] = true
    tail = tail + 1
    qx[tail], qy[tail] = x, y
  end

  for x = 0, w - 1 do push(x, 0); push(x, h - 1) end
  for y = 1, h - 2 do push(0, y); push(w - 1, y) end

  while head <= tail do
    local x, y = qx[head], qy[head]
    head = head + 1
    push(x - 1, y); push(x + 1, y)
    push(x, y - 1); push(x, y + 1)
  end

  local cleared = 0
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if visited[index(x, y)] then
        local r, g, b = data:getPixel(x, y)
        data:setPixel(x, y, r, g, b, 0)
        cleared = cleared + 1
      end
    end
  end

  local imageOk, image = pcall(love.graphics.newImage, data)
  safeRelease(data)
  if not imageOk or not image then return nil, 0 end
  if image.setFilter then image:setFilter("nearest", "nearest") end

  renderer.naturalSilhouetteCache[source] = { image = image, cleared = cleared }
  return image, cleared
end

local function drawPixelBillboard(renderer, proj, cmd, screenHeightRatio, tint)
  local image, cleared = silhouetteTexture(renderer)
  if not image then return false end

  local cx, cy = cmd.x + 0.5, cmd.y + 0.62
  local bx, by = proj:cell(cx, cy, 0.008)
  local perspective = proj.screenScale and proj:screenScale(cx, cy, 0)
                      or proj.tileW or 1
  local targetPixels = math.max(2, perspective * screenHeightRatio)
  local iw, ih = image:getDimensions()
  if not iw or not ih or iw <= 0 or ih <= 0 then return false end
  local drawScale = targetPixels / ih

  love.graphics.setColor(0, 0, 0, 0.17)
  love.graphics.ellipse("fill", bx, by + 1,
                        targetPixels * 0.29,
                        targetPixels * 0.085)

  local c = tint or { 1, 1, 1 }
  love.graphics.setColor(clamp(c[1], 0, 1),
                         clamp(c[2], 0, 1),
                         clamp(c[3], 0, 1), 1)
  love.graphics.draw(image, bx, by, 0,
                     drawScale, drawScale,
                     iw * 0.5, ih)

  renderer.lastNaturalSilhouettePixelsCleared =
    (renderer.lastNaturalSilhouettePixelsCleared or 0) + cleared
  renderer.lastNaturalSilhouetteBillboards =
    (renderer.lastNaturalSilhouetteBillboards or 0) + 1
  return true
end

local function drawTexturedBoulder(renderer, proj, cmd, variationValue)
  local rect = sourceRect(renderer, cmd.x, cmd.y)
  local mesh = rect and ensureMesh(renderer) or nil
  if not (mesh and mesh.setVertices and mesh.setTexture and renderer.source) then
    return false
  end

  local cx, cy = cmd.x + 0.5, cmd.y + 0.5
  local scale = proj.screenScale and proj:screenScale(cx, cy, 0)
                or proj.tileW or 1
  local targetSide = scale * (0.30 + variationValue * 0.045)
  local height = heightForScreen(proj, cx, cy, targetSide, 0.42)
  local footprint = 0.90 + variationValue * 0.08
  local base, top = {}, {}

  for i, p in ipairs(BOULDER_SHAPE) do
    local wx = cx + p[1] * footprint
    local wy = cy + p[2] * footprint
    local bx, by = proj:cell(wx, wy, 0.008)
    local tx, ty = proj:cell(wx, wy, height)
    base[i] = { bx, by }
    top[i] = { tx, ty }
  end

  local centerX, centerY = proj:cell(cx, cy, 0.004)
  love.graphics.setColor(0, 0, 0, 0.14)
  love.graphics.ellipse("fill", centerX, centerY + 1,
                        scale * 0.34, scale * 0.11)

  local edges = {}
  for i = 1, #BOULDER_SHAPE do
    local j = i % #BOULDER_SHAPE + 1
    edges[#edges + 1] = {
      i = i, j = j,
      score = (base[i][2] + base[j][2]) * 0.5,
    }
  end
  table.sort(edges, function(a, b) return a.score > b.score end)
  for n = 1, 4 do
    local e = edges[n]
    local i, j = e.i, e.j
    local shade = 0.34 + (n - 1) * 0.025
    love.graphics.setColor(shade, shade * 1.03, shade * 1.01, 1)
    love.graphics.polygon("fill",
      base[i][1], base[i][2], base[j][1], base[j][2],
      top[j][1], top[j][2], top[i][1], top[i][2])
  end

  local sx, sy, sw, sh = rect[1], rect[2], rect[3], rect[4]
  local vertices = {}
  for i, p in ipairs(BOULDER_SHAPE) do
    vertices[i] = {
      top[i][1], top[i][2],
      (sx + (p[1] + 0.5) * sw) / renderer.sourceW,
      (sy + (p[2] + 0.5) * sh) / renderer.sourceH,
      1, 1, 1, 1,
    }
  end
  local ok = pcall(function()
    mesh:setVertices(vertices)
    mesh:setTexture(renderer.source)
  end)
  if not ok then return false end
  love.graphics.setColor(0.98, 0.99, 0.97, 1)
  love.graphics.draw(mesh)
  return true
end

local function variation(cmd)
  local x = math.floor(tonumber(cmd and cmd.x) or 0)
  local y = math.floor(tonumber(cmd and cmd.y) or 0)
  return ((x * 17 + y * 29) % 5) / 4
end

local function motifForCommand(cmd)
  if not (cmd and cmd.scene and cmd.scene.map) then return nil end
  local ox = (tonumber(cmd.scene.ox) or 0) / CELL
  local oy = (tonumber(cmd.scene.oy) or 0) / CELL
  local cx = math.floor((tonumber(cmd.x) or 0) - ox + 0.001)
  local cy = math.floor((tonumber(cmd.y) or 0) - oy + 0.001)
  return VanillaMotifs.cellMotif(cmd.scene.map, cx, cy)
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
    self.lastNaturalSilhouetteBillboards = 0
    self.lastNaturalSilhouettePixelsCleared = 0
  end

  local baseInvalidate = renderer.invalidate
  renderer.invalidate = function(self)
    if self.naturalFormMesh and self.naturalFormMesh.release then
      pcall(self.naturalFormMesh.release, self.naturalFormMesh)
    end
    self.naturalFormMesh = nil
    if self.naturalSilhouetteCache then
      for _, cached in pairs(self.naturalSilhouetteCache) do
        safeRelease(cached and cached.image)
      end
    end
    self.naturalSilhouetteCache = nil
    return baseInvalidate(self)
  end

  local baseDrawVegetation = renderer.drawVegetation
  renderer.drawVegetation = function(self, proj, cmd)
    -- Preserve the canonical 16x16 Red tree silhouette instead of forcing the
    -- source pixels through the old octagonal card. Perspective changes only
    -- the uniform screen scale; the sprite's aspect ratio and pixel geometry
    -- remain intact.
    local ratio = ({ 1.28, 1.55, 1.82 })[proj.level] or 1.55
    if drawPixelBillboard(self, proj, cmd, ratio,
                          { 0.98, 1.00, 0.97 }) then
      self.lastNaturalVegetationCards =
        (self.lastNaturalVegetationCards or 0) + 1
      return true
    end

    -- Compatibility only for test/engine surfaces that cannot expose ImageData.
    local v = variation(cmd)
    ratio = ratio * (0.98 + v * 0.03)
    local width = ({ 0.94, 1.02, 1.08 })[proj.level] or 1.02
    if drawTexturedCard(self, proj, cmd, ratio, width,
                        { 0.96, 1.00, 0.94 }, 1.55) then
      self.lastNaturalVegetationCards =
        (self.lastNaturalVegetationCards or 0) + 1
      self.lastNaturalCardFallbacks =
        (self.lastNaturalCardFallbacks or 0) + 1
      return true
    end

    self.lastNaturalCardFallbacks = (self.lastNaturalCardFallbacks or 0) + 1
    return baseDrawVegetation(self, proj, cmd)
  end

  local baseDrawLowPrism = renderer.drawLowPrism
  renderer.drawLowPrism = function(self, proj, cmd, height, topColor)
    -- Only the verified canonical boulder motif receives this 3D rock path.
    if motifForCommand(cmd) == "boulder" then
      local v = variation(cmd)
      if drawTexturedBoulder(self, proj, cmd, v) then
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
