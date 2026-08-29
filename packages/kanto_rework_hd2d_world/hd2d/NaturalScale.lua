local VanillaMotifs = require("hd2d.VanillaMotifs")

local NaturalScale = {}
local CELL = 16

local OUTDOOR = {
  OVERWORLD = true,
  FOREST = true,
  SHIP_PORT = true,
  PLATEAU = true,
}

local ROCK_SHAPE = {
  { -0.22, -0.44 }, { 0.20, -0.42 },
  { 0.44, -0.19 }, { 0.40, 0.24 },
  { 0.18, 0.43 }, { -0.25, 0.40 },
  { -0.45, 0.17 }, { -0.40, -0.22 },
}

local function variation(cmd, salt)
  local x = math.floor(tonumber(cmd and cmd.x) or 0)
  local y = math.floor(tonumber(cmd and cmd.y) or 0)
  return ((x * 37 + y * 53 + (salt or 0) * 19) % 101) / 100
end

local function localCell(cmd)
  if not (cmd and cmd.scene and cmd.scene.map) then return nil end
  local ox = (tonumber(cmd.scene.ox) or 0) / CELL
  local oy = (tonumber(cmd.scene.oy) or 0) / CELL
  local cx = math.floor((tonumber(cmd.x) or 0) - ox + 0.001)
  local cy = math.floor((tonumber(cmd.y) or 0) - oy + 0.001)
  return cmd.scene.map, cx, cy
end

local function isOutdoor(map)
  return OUTDOOR[map and map.def and map.def.tileset] == true
end

local function transformedProjection(proj, scaleFactor, dx, dy)
  scaleFactor = scaleFactor or 1
  dx, dy = dx or 0, dy or 0
  if not proj or (math.abs(scaleFactor - 1) < 0.0001
      and math.abs(dx) < 0.0001 and math.abs(dy) < 0.0001) then return proj end
  local proxy = { level = proj.level, tileW = proj.tileW, tileH = proj.tileH,
                  elevation = proj.elevation, spriteScale = proj.spriteScale }
  proxy.cell = function(_, x, y, z) return proj:cell(x + dx, y + dy, z) end
  proxy.worldPixel = function(_, wx, wy, z)
    return proj:worldPixel(wx + dx * CELL, wy + dy * CELL, z)
  end
  proxy.quad = function(_, x0, y0, x1, y1, z)
    return proj:quad(x0 + dx, y0 + dy, x1 + dx, y1 + dy, z)
  end
  proxy.cellPolygon = function(_, x, y, z)
    return proj:cellPolygon(x + dx, y + dy, z)
  end
  proxy.depth = function(_, x, y, bias) return proj:depth(x + dx, y + dy, bias) end
  proxy.visibleRadius = function() return proj:visibleRadius() end
  proxy.spriteScaleAt = function(_, x, y, z)
    local s = proj.spriteScaleAt and proj:spriteScaleAt(x + dx, y + dy, z) or 1
    return s * scaleFactor
  end
  proxy.screenScale = function(_, x, y, z)
    local s = proj.screenScale and proj:screenScale(x + dx, y + dy, z) or proj.tileW or 1
    return s * scaleFactor
  end
  return setmetatable(proxy, { __index = proj })
end

local function drawFlatAtlasDecal(renderer, proj, cmd, topColor)
  if not (cmd and cmd.atlasTexture and renderer.drawTexturedQuad) then return false end
  local rect = { 0, 0, CELL, CELL, atlasImage = cmd.atlasTexture }
  return renderer:drawTexturedQuad(proj, cmd.x, cmd.y, 0.006, rect, topColor)
end

local function heightForScreen(proj, cx, cy, targetPixels, fallback)
  if not (proj and type(proj.cell) == "function") then return fallback end
  local _, baseY = proj:cell(cx, cy, 0.006)
  if type(baseY) ~= "number" then return fallback end
  local lo, hi = 0.015, 1.20
  for _ = 1, 10 do
    local mid = (lo + hi) * 0.5
    local _, topY = proj:cell(cx, cy, mid)
    if type(topY) ~= "number" then return fallback end
    if math.abs(baseY - topY) < targetPixels then lo = mid else hi = mid end
  end
  return (lo + hi) * 0.5
end

local function ensureRockMesh(renderer)
  if renderer.naturalScaleRockMesh then return renderer.naturalScaleRockMesh end
  if not (love and love.graphics and love.graphics.newMesh) then return nil end
  local seed = {}
  for i = 1, #ROCK_SHAPE do
    seed[i] = { 0, 0, 0, 0, 1, 1, 1, 1 }
  end
  local ok, mesh = pcall(love.graphics.newMesh, seed, "fan", "dynamic")
  if not ok then return nil end
  renderer.naturalScaleRockMesh = mesh
  return mesh
end

local function drawSlopedRock(renderer, proj, cmd)
  local texture = cmd and cmd.atlasTexture
  local mesh = texture and ensureRockMesh(renderer) or nil
  if not (mesh and mesh.setVertices and mesh.setTexture) then return false end

  local v = variation(cmd, 1)
  local skew = variation(cmd, 2) - 0.5
  local cx, cy = cmd.x + 0.5, cmd.y + 0.51
  local scale = proj.screenScale and proj:screenScale(cx, cy, 0) or proj.tileW or 1
  local targetRise = scale * (0.075 + v * 0.025)
  local height = heightForScreen(proj, cx, cy, targetRise, 0.14)
  local footprint = 0.91 + v * 0.05
  local inset = 0.58 + variation(cmd, 3) * 0.09
  local topShiftX = skew * 0.055
  local topShiftY = -0.035 - variation(cmd, 4) * 0.025
  local base, top = {}, {}

  for i, p in ipairs(ROCK_SHAPE) do
    local bwx = cx + p[1] * footprint
    local bwy = cy + p[2] * footprint
    local twx = cx + p[1] * footprint * inset + topShiftX
    local twy = cy + p[2] * footprint * inset + topShiftY
    local bx, by = proj:cell(bwx, bwy, 0.006)
    local tx, ty = proj:cell(twx, twy, height)
    base[i] = { bx, by }
    top[i] = { tx, ty }
  end

  local sx, sy = proj:cell(cx, cy, 0.003)
  love.graphics.setColor(0, 0, 0, 0.15)
  love.graphics.ellipse("fill", sx, sy + 1, scale * 0.35, scale * 0.095)

  local edges = {}
  for i = 1, #ROCK_SHAPE do
    local j = i % #ROCK_SHAPE + 1
    edges[#edges + 1] = { i = i, j = j,
      score = (base[i][2] + base[j][2]) * 0.5 }
  end
  table.sort(edges, function(a, b) return a.score > b.score end)
  for n = 1, 5 do
    local e = edges[n]
    local shade = 0.31 + (n - 1) * 0.022
    love.graphics.setColor(shade, shade * 1.025, shade * 1.01, 1)
    love.graphics.polygon("fill",
      base[e.i][1], base[e.i][2], base[e.j][1], base[e.j][2],
      top[e.j][1], top[e.j][2], top[e.i][1], top[e.i][2])
  end

  local vertices = {}
  for i, p in ipairs(ROCK_SHAPE) do
    vertices[i] = {
      top[i][1], top[i][2], p[1] + 0.5, p[2] + 0.5,
      1, 1, 1, 1,
    }
  end
  local ok = pcall(function()
    mesh:setVertices(vertices)
    mesh:setTexture(texture)
  end)
  if not ok then return false end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(mesh)
  return true
end

function NaturalScale.apply(renderer)
  if not renderer or renderer.__naturalScaleApplied then return renderer end
  renderer.__naturalScaleApplied = true

  local baseResetMetrics = renderer.resetMetrics
  renderer.resetMetrics = function(self)
    baseResetMetrics(self)
    self.lastScaledTrees = 0
    self.lastFlattenedBoulders = 0
    self.lastGroundedGenericBoundaries = 0
    self.lastOrganicTreeOffsets = 0
    self.lastSlopedBoulders = 0
  end

  local baseInvalidate = renderer.invalidate
  renderer.invalidate = function(self)
    if self.naturalScaleRockMesh and self.naturalScaleRockMesh.release then
      pcall(self.naturalScaleRockMesh.release, self.naturalScaleRockMesh)
    end
    self.naturalScaleRockMesh = nil
    return baseInvalidate(self)
  end

  local baseDrawVegetation = renderer.drawVegetation
  renderer.drawVegetation = function(self, proj, cmd)
    -- Preserve the exact vanilla silhouette but break the repeated fence-post
    -- read with projection-only sub-cell offsets and tiny deterministic scale
    -- variation. Source sampling, collision and map coordinates never move.
    local v = variation(cmd, 0)
    local dx = (variation(cmd, 5) - 0.5) * 0.090
    local dy = (variation(cmd, 6) - 0.5) * 0.040
    local factor = (0.70 + v * 0.045) * (0.955 + variation(cmd, 7) * 0.085)
    self.lastScaledTrees = (self.lastScaledTrees or 0) + 1
    self.lastOrganicTreeOffsets = (self.lastOrganicTreeOffsets or 0) + 1
    return baseDrawVegetation(self, transformedProjection(proj, factor, dx, dy), cmd)
  end

  local baseDrawLowPrism = renderer.drawLowPrism
  renderer.drawLowPrism = function(self, proj, cmd, height, topColor)
    local map, cx, cy = localCell(cmd)
    local motif = map and VanillaMotifs.cellMotif(map, cx, cy) or nil
    if motif == "boulder" then
      -- TEST11 live footage showed the former equal-footprint extrusion reading
      -- as a puck/cylinder. The atlas top is now inset and shifted over a wider
      -- base, creating sloped faces and an irregular low rock mound.
      self.lastFlattenedBoulders = (self.lastFlattenedBoulders or 0) + 1
      if cmd and cmd.atlasTexture and drawSlopedRock(self, proj, cmd) then
        self.lastSlopedBoulders = (self.lastSlopedBoulders or 0) + 1
        return true
      end
      return baseDrawLowPrism(self, transformedProjection(proj, 0.42),
                              cmd, height, topColor)
    end

    -- Unknown outdoor boundary/obstacle cells have no evidence of vertical
    -- topology. Preserve their atlas pixels as a near-ground decal instead of
    -- fabricating a grey wall.
    if map and isOutdoor(map) and motif == nil then
      if drawFlatAtlasDecal(self, proj, cmd, topColor) then
        self.lastGroundedGenericBoundaries =
          (self.lastGroundedGenericBoundaries or 0) + 1
        return true
      end
      self.lastGroundedGenericBoundaries =
        (self.lastGroundedGenericBoundaries or 0) + 1
      return baseDrawLowPrism(self, proj, cmd, 0.004, topColor)
    end

    return baseDrawLowPrism(self, proj, cmd, height, topColor)
  end

  return renderer
end

return NaturalScale
