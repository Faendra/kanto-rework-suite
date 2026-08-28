local SceneStyle = {}

local CELL = 16

local C = {
  wall = { 0.76, 0.76, 0.69 },
  wallSide = { 0.49, 0.52, 0.49 },
  roof = { 0.39, 0.38, 0.33 },
  roofFar = { 0.28, 0.30, 0.29 },
  civicWall = { 0.72, 0.77, 0.72 },
  civicRoof = { 0.30, 0.40, 0.39 },
  door = { 0.72, 0.45, 0.12 },
  window = { 0.48, 0.68, 0.69 },
  trunk = { 0.32, 0.21, 0.12 },
  leafDark = { 0.12, 0.34, 0.18 },
  leaf = { 0.22, 0.49, 0.23 },
  leafLight = { 0.38, 0.64, 0.31 },
  rockSide = { 0.34, 0.38, 0.38 },
  rockFallback = { 0.59, 0.62, 0.59 },
  shadow = { 0.018, 0.022, 0.026 },
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function setColor(c, alpha, mul)
  mul = mul or 1
  love.graphics.setColor(clamp(c[1] * mul, 0, 1),
                         clamp(c[2] * mul, 0, 1),
                         clamp(c[3] * mul, 0, 1), alpha or 1)
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

local function flipVerticalFace(points)
  return {
    points[7], points[8],
    points[5], points[6],
    points[3], points[4],
    points[1], points[2],
  }
end

local function sourceRect(renderer, worldX, worldY, worldW, worldH)
  local sx = worldX * CELL - renderer.sourceCamX
  local sy = worldY * CELL - renderer.sourceCamY
  local sw = worldW * CELL
  local sh = worldH * CELL
  if sx < 0 or sy < 0 or sx + sw > renderer.sourceW or sy + sh > renderer.sourceH then
    return nil
  end
  return { sx, sy, sw, sh }
end

local function texturedFace(renderer, points, rect, tint, alpha)
  if not (renderer.mesh and rect and renderer.mesh.setVertices
          and renderer.mesh.setTexture and renderer.source) then
    return false
  end
  local sx, sy, sw, sh = rect[1], rect[2], rect[3], rect[4]
  local u0, v0 = sx / renderer.sourceW, sy / renderer.sourceH
  local u1, v1 = (sx + sw) / renderer.sourceW, (sy + sh) / renderer.sourceH
  local vertices = {
    { points[1], points[2], u0, v0, 1, 1, 1, 1 },
    { points[3], points[4], u1, v0, 1, 1, 1, 1 },
    { points[5], points[6], u1, v1, 1, 1, 1, 1 },
    { points[7], points[8], u0, v1, 1, 1, 1, 1 },
  }
  local ok = pcall(function()
    renderer.mesh:setVertices(vertices)
    renderer.mesh:setTexture(renderer.source)
  end)
  if not ok then return false end
  setColor(tint or { 1, 1, 1 }, alpha or 1)
  love.graphics.draw(renderer.mesh)
  return true
end

local function drawSouthPanel(proj, x0, x1, y, z0, z1, color, alpha)
  setColor(color, alpha or 1)
  drawPoly(southWall(proj, x0, x1, y + 0.003, z0, z1))
end

local function findDoorX(classifier, map, mass)
  for cx = mass.minX, mass.maxX do
    if classifier.isTraversalThreshold(map, cx, mass.maxY + 1) then
      return cx + 0.5
    end
  end
  return (mass.minX + mass.maxX + 1) * 0.5
end

local function structureShadow(proj, x0, y0, x1, y1, level)
  local dx = ({ 0.22, 0.30, 0.38 })[level] or 0.30
  local dy = dx * 0.62
  setColor(C.shadow, 0.15)
  drawPoly(proj:quad(x0 + dx, y0 + dy, x1 + dx, y1 + dy, 0.005))
  setColor(C.shadow, 0.055)
  drawPoly(proj:quad(x0 + dx * 1.55, y0 + dy * 1.55,
                     x1 + dx * 1.55, y1 + dy * 1.55, 0.004))
end

local function crownPoints(cx, cy, w, h)
  local x0, x1 = cx - w * 0.5, cx + w * 0.5
  local y0, y1 = cy - h * 0.5, cy + h * 0.5
  local sx = w * 0.18
  local sy = h * 0.20
  return {
    x0 + sx, y0,
    x1 - sx, y0,
    x1, y0 + sy,
    x1, y1 - sy,
    x1 - sx, y1,
    x0 + sx, y1,
    x0, y1 - sy,
    x0, y0 + sy,
  }
end

local function pixelCrown(cx, cy, w, h, color, alpha)
  setColor(color, alpha or 1)
  drawPoly(crownPoints(cx, cy, w, h))
end

local function texturedCrown(renderer, cx, cy, w, h, rect)
  if not (rect and love.graphics.stencil and love.graphics.setStencilTest) then
    return false
  end
  local crown = crownPoints(cx, cy, w, h)
  local quad = {
    cx - w * 0.5, cy - h * 0.5,
    cx + w * 0.5, cy - h * 0.5,
    cx + w * 0.5, cy + h * 0.5,
    cx - w * 0.5, cy + h * 0.5,
  }
  local textured = false
  local ok = pcall(function()
    love.graphics.stencil(function()
      love.graphics.polygon("fill", crown)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    textured = texturedFace(renderer, quad, rect, { 0.98, 1.00, 0.96 }, 1)
    love.graphics.setStencilTest()
  end)
  if not ok then
    pcall(love.graphics.setStencilTest)
    return false
  end
  return textured
end

local function installConservativeNaturalSemantics(classifier)
  if classifier.__sceneStyleNaturalSemantics then return end
  classifier.__sceneStyleNaturalSemantics = true
  local baseClassify = classifier.classify
  classifier.classify = function(map, cx, cy)
    local material = baseClassify(map, cx, cy)
    if material.kind == "solid" and material.family == "vegetation" then
      local mass = classifier.massInfo(map, cx, cy)
      -- TEST2's live Pallet capture proves that a repeated edge collision mass
      -- can be rock/border scenery. Until Gen1 exposes explicit vegetation
      -- metadata, edge-touching masses stay textured low relief; only repeated
      -- interior masses become upright vegetation silhouettes.
      if mass and mass.touchesEdge then
        material.family = "boundary"
        material.heightScale = 1.18
      end
    end
    return material
  end
end

function SceneStyle.apply(renderer)
  if not renderer or renderer.__sceneStyleApplied then return renderer end
  renderer.__sceneStyleApplied = true
  installConservativeNaturalSemantics(renderer.MaterialClassifier)

  renderer.drawStructure = function(self, proj, cmd)
    local mass = cmd.mass
    local ox = cmd.scene.ox / CELL
    local oy = cmd.scene.oy / CELL
    local x0 = mass.minX + ox
    local x1 = mass.maxX + 1 + ox
    local y0 = mass.minY + oy
    local y1 = mass.maxY + 1 + oy
    local spanX = mass.spanX or (x1 - x0)
    local spanY = mass.spanY or (y1 - y0)
    local civic = spanX >= 5 or spanY >= 4
    local levelScale = ({ 0.94, 1.00, 1.07 })[proj.level] or 1
    local wallH = (civic and 0.78 or 0.86) * levelScale
    local ridgeH = wallH + (civic and 0.38 or 0.48) * levelScale
    local ridgeY = y0 + (y1 - y0) * 0.48
    local wallColor = civic and C.civicWall or C.wall
    local roofColor = civic and C.civicRoof or C.roof

    structureShadow(proj, x0, y0, x1, y1, proj.level)

    local roofRect = sourceRect(self, x0, y0, x1 - x0, math.min(1, y1 - y0))
    local frontRect = sourceRect(self, x0, math.max(y0, y1 - 1), x1 - x0, 1)

    local n0x, n0y = proj:cell(x0 - 0.10, y0 - 0.05, wallH)
    local n1x, n1y = proj:cell(x1 + 0.10, y0 - 0.05, wallH)
    local r1x, r1y = proj:cell(x1 + 0.10, ridgeY, ridgeH)
    local r0x, r0y = proj:cell(x0 - 0.10, ridgeY, ridgeH)
    local farRoof = { n0x, n0y, n1x, n1y, r1x, r1y, r0x, r0y }
    if not texturedFace(self, farRoof, roofRect, { 0.76, 0.78, 0.76 }, 1) then
      setColor(C.roofFar)
      drawPoly(farRoof)
    end

    local frontWall = southWall(proj, x0, x1, y1, 0, wallH)
    local texturedFront = texturedFace(self, flipVerticalFace(frontWall), frontRect,
                                       { 0.92, 0.93, 0.89 }, 1)
    if not texturedFront then
      setColor(wallColor)
      drawPoly(frontWall)
    end

    setColor(C.wallSide)
    drawPoly(eastWall(proj, x1, y0, y1, 0, wallH))

    local f0x, f0y = proj:cell(x0 - 0.12, y1 + 0.08, wallH)
    local f1x, f1y = proj:cell(x1 + 0.12, y1 + 0.08, wallH)
    local rr1x, rr1y = proj:cell(x1 + 0.10, ridgeY, ridgeH)
    local rr0x, rr0y = proj:cell(x0 - 0.10, ridgeY, ridgeH)
    local nearRoof = { rr0x, rr0y, rr1x, rr1y, f1x, f1y, f0x, f0y }
    if not texturedFace(self, nearRoof, roofRect, { 1.00, 1.00, 0.98 }, 1) then
      setColor(roofColor)
      drawPoly(nearRoof)
    end

    local e0x, e0y = proj:cell(x1 + 0.105, y0, wallH)
    local e1x, e1y = proj:cell(x1 + 0.105, y1, wallH)
    local erx, ery = proj:cell(x1 + 0.105, ridgeY, ridgeH)
    setColor(C.roofFar, 1, 0.90)
    drawPoly({ e0x, e0y, e1x, e1y, erx, ery })

    local doorX = findDoorX(self.MaterialClassifier, cmd.scene.map, mass) + ox
    drawSouthPanel(proj, doorX - 0.245, doorX + 0.245, y1 + 0.008,
                   0.01, wallH * 0.62, C.door, texturedFront and 0.72 or 1)
    if x1 - x0 >= 2.2 then
      local function windowAt(cx)
        if math.abs(cx - doorX) < 0.62 then return end
        drawSouthPanel(proj, cx - 0.21, cx + 0.21, y1 + 0.009,
                       wallH * 0.31, wallH * 0.56, C.window,
                       texturedFront and 0.42 or 1)
      end
      windowAt(x0 + 0.62)
      windowAt(x1 - 0.62)
    end

    if love.graphics.line and love.graphics.setLineWidth then
      love.graphics.setLineWidth(math.max(1, proj.tileW * 0.020))
      setColor(C.shadow, 0.33)
      love.graphics.line(f0x, f0y, f1x, f1y)
      setColor({ 1, 1, 1 }, 0.18)
      love.graphics.line(rr0x, rr0y, rr1x, rr1y)
      local wx0, wy0 = proj:cell(x0, y1 + 0.012, wallH)
      local wx1, wy1 = proj:cell(x1, y1 + 0.012, wallH)
      setColor({ 1, 1, 1 }, 0.10)
      love.graphics.line(wx0, wy0, wx1, wy1)
    end
  end

  renderer.drawVegetation = function(self, proj, cmd)
    local x, y = cmd.x, cmd.y
    local cx, cy = x + 0.5, y + 0.58
    local levelScale = ({ 0.94, 1.00, 1.08 })[proj.level] or 1

    setColor(C.shadow, 0.12)
    drawPoly(proj:quad(x + 0.12, y + 0.20,
                       x + 0.92, y + 0.86, 0.004))

    local bx, by = proj:cell(cx, cy, 0)
    local tx, ty = proj:cell(cx, cy, 0.48 * levelScale)
    local halfTrunk = proj.tileW * 0.040
    setColor(C.trunk)
    drawPoly({ bx - halfTrunk, by, bx + halfTrunk, by,
               tx + halfTrunk, ty, tx - halfTrunk, ty })

    local c1x, c1y = proj:cell(cx - 0.03, cy, 0.49 * levelScale)
    local c2x, c2y = proj:cell(cx + 0.02, cy, 0.66 * levelScale)
    local c3x, c3y = proj:cell(cx - 0.01, cy, 0.83 * levelScale)
    local ownRect = sourceRect(self, x, y, 1, 1)

    pixelCrown(c1x - proj.tileW * 0.06, c1y + proj.tileW * 0.015,
               proj.tileW * 0.66, proj.tileW * 0.35, C.leafDark, 1)
    if not texturedCrown(self, c2x + proj.tileW * 0.035, c2y,
                         proj.tileW * 0.72, proj.tileW * 0.43, ownRect) then
      pixelCrown(c2x + proj.tileW * 0.035, c2y,
                 proj.tileW * 0.72, proj.tileW * 0.43, C.leaf, 1)
    end
    pixelCrown(c3x - proj.tileW * 0.02, c3y - proj.tileW * 0.008,
               proj.tileW * 0.48, proj.tileW * 0.26, C.leafLight, 0.78)
  end

  renderer.drawLowPrism = function(self, proj, cmd, height, topColor)
    local x, y = cmd.x, cmd.y
    height = height or 0.17
    setColor(C.shadow, 0.09)
    drawPoly(proj:quad(x + 0.10, y + 0.12,
                       x + 0.96, y + 0.96, 0.004))
    setColor(C.rockSide)
    drawPoly(southWall(proj, x, x + 1, y + 1, 0, height))
    drawPoly(eastWall(proj, x + 1, y, y + 1, 0, height))

    local own = sourceRect(self, x, y, 1, 1)
    local points = proj:cellPolygon(x, y, height)
    if not texturedFace(self, points, own, { 0.94, 0.95, 0.94 }, 1) then
      setColor(topColor or C.rockFallback)
      drawPoly(points)
    end
  end

  return renderer
end

return SceneStyle
