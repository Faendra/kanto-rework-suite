local AtlasWorld = {}

local CELL = 16

local function localCell(cmd)
  if not (cmd and cmd.scene) then return nil end
  local ox = (tonumber(cmd.scene.ox) or 0) / CELL
  local oy = (tonumber(cmd.scene.oy) or 0) / CELL
  local cx = cmd.cx
  local cy = cmd.cy
  if cx == nil and cmd.x ~= nil then cx = math.floor((cmd.x - ox) + 0.0001) end
  if cy == nil and cmd.y ~= nil then cy = math.floor((cmd.y - oy) + 0.0001) end
  return cx, cy
end

local function withCellTexture(renderer, cmd, fn)
  local tex = cmd and cmd.atlasTexture
  if not tex then return fn() end

  local source = renderer.source
  local sourceW, sourceH = renderer.sourceW, renderer.sourceH
  local sourceCamX, sourceCamY = renderer.sourceCamX, renderer.sourceCamY

  renderer.source = tex
  renderer.sourceW, renderer.sourceH = CELL, CELL
  renderer.sourceCamX = (tonumber(cmd.x) or 0) * CELL
  renderer.sourceCamY = (tonumber(cmd.y) or 0) * CELL
  local ok, result = pcall(fn)
  renderer.source = source
  renderer.sourceW, renderer.sourceH = sourceW, sourceH
  renderer.sourceCamX, renderer.sourceCamY = sourceCamX, sourceCamY
  if not ok then error(result, 0) end
  return result
end

local function drawAtlasQuad(renderer, proj, x, y, z, rect, fallback)
  local image = rect and rect.atlasImage
  if not (image and renderer.mesh and renderer.mesh.setVertices
          and renderer.mesh.setTexture) then return nil end
  local points = proj:cellPolygon(x, y, z)
  local vertices = {
    { points[1], points[2], 0, 0, 1, 1, 1, 1 },
    { points[3], points[4], 1, 0, 1, 1, 1, 1 },
    { points[5], points[6], 1, 1, 1, 1, 1, 1 },
    { points[7], points[8], 0, 1, 1, 1, 1, 1 },
  }
  local ok = pcall(function()
    renderer.mesh:setVertices(vertices)
    renderer.mesh:setTexture(image)
  end)
  if not ok then return false end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(renderer.mesh)
  return true
end

function AtlasWorld.apply(renderer, AtlasSource)
  if not renderer or renderer.__atlasWorldApplied then return renderer end
  renderer.__atlasWorldApplied = true
  renderer.atlasSource = AtlasSource

  local baseResetMetrics = renderer.resetMetrics
  renderer.resetMetrics = function(self)
    baseResetMetrics(self)
    self.lastAtlasCellTextures = 0
    self.lastAtlasGroundCells = 0
    self.lastAtlasNaturalObjects = 0
  end

  local baseInvalidate = renderer.invalidate
  renderer.invalidate = function(self)
    if AtlasSource and AtlasSource.invalidate then AtlasSource.invalidate(self) end
    return baseInvalidate(self)
  end

  local baseBuildScene = renderer.buildScene
  renderer.buildScene = function(self, ctx, proj)
    local ground, objects, scenes = baseBuildScene(self, ctx, proj)

    for _, cmd in ipairs(ground or {}) do
      local kind = cmd.material and cmd.material.kind
      -- Solid cells deliberately keep the existing donor-floor path so an
      -- object's pixels are never stamped underneath its reconstructed volume.
      if kind ~= "solid" and cmd.scene and cmd.scene.map then
        local tex = AtlasSource.cellTexture(self, cmd.scene.map, cmd.cx, cmd.cy)
        if tex then
          cmd.rect = { 0, 0, CELL, CELL, atlasImage = tex }
          self.lastAtlasGroundCells = self.lastAtlasGroundCells + 1
        end
      end
    end

    for _, cmd in ipairs(objects or {}) do
      if (cmd.kind == "vegetation" or cmd.kind == "boundary" or cmd.kind == "obstacle")
         and cmd.scene and cmd.scene.map then
        local cx, cy = localCell(cmd)
        if cx ~= nil and cy ~= nil then
          local tex = AtlasSource.cellTexture(self, cmd.scene.map, cx, cy)
          if tex then
            cmd.atlasTexture = tex
            self.lastAtlasNaturalObjects = self.lastAtlasNaturalObjects + 1
          end
        end
      end
    end
    return ground, objects, scenes
  end

  local baseDrawTexturedQuad = renderer.drawTexturedQuad
  renderer.drawTexturedQuad = function(self, proj, x, y, z, rect, fallback)
    local result = drawAtlasQuad(self, proj, x, y, z, rect, fallback)
    if result ~= nil then return result end
    return baseDrawTexturedQuad(self, proj, x, y, z, rect, fallback)
  end

  local baseDrawVegetation = renderer.drawVegetation
  renderer.drawVegetation = function(self, proj, cmd)
    return withCellTexture(self, cmd, function()
      return baseDrawVegetation(self, proj, cmd)
    end)
  end

  local baseDrawLowPrism = renderer.drawLowPrism
  renderer.drawLowPrism = function(self, proj, cmd, height, topColor)
    return withCellTexture(self, cmd, function()
      return baseDrawLowPrism(self, proj, cmd, height, topColor)
    end)
  end

  return renderer
end

return AtlasWorld
