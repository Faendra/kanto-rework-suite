local AtlasWorld = {}

local CELL = 16
local OUTDOOR = {
  OVERWORLD = true,
  FOREST = true,
  SHIP_PORT = true,
  PLATEAU = true,
}

local function mapTileset(map)
  return map and map.def and map.def.tileset or nil
end

local function mapInBounds(map, x, y)
  if not map then return false end
  if type(map.inBounds) == "function" then
    local ok, value = pcall(map.inBounds, map, x, y)
    if ok then return value == true end
  end
  return x >= 0 and y >= 0
     and x < (tonumber(map.widthCells) or 0)
     and y < (tonumber(map.heightCells) or 0)
end

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

local function donorCell(classifier, map, cx, cy)
  local grassCandidate
  for radius = 1, 3 do
    for dy = -radius, radius do
      for dx = -radius, radius do
        if math.abs(dx) == radius or math.abs(dy) == radius then
          local nx, ny = cx + dx, cy + dy
          if mapInBounds(map, nx, ny) then
            local material = classifier.classify(map, nx, ny)
            if material.kind == "ground" then return nx, ny end
            if not grassCandidate and material.kind == "grass" then
              grassCandidate = { nx, ny }
            end
          end
        end
      end
    end
  end
  if grassCandidate then return grassCandidate[1], grassCandidate[2] end
  return nil
end

local function allScenesDirect(ctx, AtlasSource)
  local state = ctx and ctx.state
  if not (state and state.map and AtlasSource.available(state.map)) then
    return false
  end
  for _, nb in ipairs(state.neighbors or {}) do
    if nb.map and not AtlasSource.available(nb.map) then return false end
  end
  return true
end

local function prepareDirectWindow(renderer, ctx)
  local vw = tonumber(ctx.vw) or 160
  local vh = tonumber(ctx.vh) or 144
  local padX = math.max(0, ((tonumber(renderer.sourceW) or vw) - vw) * 0.5)
  local padY = math.max(0, ((tonumber(renderer.sourceH) or vh) - vh) * 0.5)
  renderer.sourceCamX = (tonumber(ctx.cam and ctx.cam.x) or 0) - padX
  renderer.sourceCamY = (tonumber(ctx.bgY)
      or tonumber(ctx.cam and ctx.cam.y) or 0) - padY
  renderer.lastOutdoor = OUTDOOR[mapTileset(ctx.state and ctx.state.map)] == true
end

local function withTexture(renderer, image, worldX, worldY, fn)
  if not image then return fn() end

  local source = renderer.source
  local sourceW, sourceH = renderer.sourceW, renderer.sourceH
  local sourceCamX, sourceCamY = renderer.sourceCamX, renderer.sourceCamY
  local w, h = CELL, CELL
  if image.getDimensions then
    local ok, iw, ih = pcall(image.getDimensions, image)
    if ok and iw and ih then w, h = iw, ih end
  end

  renderer.source = image
  renderer.sourceW, renderer.sourceH = w, h
  renderer.sourceCamX = (tonumber(worldX) or 0) * CELL
  renderer.sourceCamY = (tonumber(worldY) or 0) * CELL
  local ok, result = pcall(fn)
  renderer.source = source
  renderer.sourceW, renderer.sourceH = sourceW, sourceH
  renderer.sourceCamX, renderer.sourceCamY = sourceCamX, sourceCamY
  if not ok then error(result, 0) end
  return result
end

local function withoutFlatSource(renderer, fn)
  local source = renderer.source
  renderer.source = nil
  local ok, result = pcall(fn)
  renderer.source = source
  if not ok then error(result, 0) end
  return result
end

local function drawAtlasQuad(renderer, proj, x, y, z, rect)
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
    self.lastAtlasRegionTextures = 0
    self.lastAtlasGroundCells = 0
    self.lastAtlasDonorGroundCells = 0
    self.lastAtlasNaturalObjects = 0
    self.lastAtlasStructures = 0
    self.lastAtlasDirectFrames = 0
    self.lastCompatibilityCaptureFrames = 0
    self.lastFlatSourceFallbacks = 0
    self._atlasDirectFrame = false
  end

  local baseInvalidate = renderer.invalidate
  renderer.invalidate = function(self)
    if AtlasSource and AtlasSource.invalidate then AtlasSource.invalidate(self) end
    return baseInvalidate(self)
  end

  -- TEST8's nominal path no longer asks Gen1Recomp to rasterize the flat map
  -- into our source canvas. We still preserve the old capture as a compatibility
  -- fallback for an engine/test map that does not expose image/quads/tileAt.
  local baseCaptureTerrain = renderer.captureTerrain
  renderer.captureTerrain = function(self, ctx)
    self._atlasDirectFrame = allScenesDirect(ctx, AtlasSource)
    if self._atlasDirectFrame then
      prepareDirectWindow(self, ctx)
      self.lastAtlasDirectFrames = (self.lastAtlasDirectFrames or 0) + 1
      return true
    end
    self.lastCompatibilityCaptureFrames =
      (self.lastCompatibilityCaptureFrames or 0) + 1
    return baseCaptureTerrain(self, ctx)
  end

  local baseBuildScene = renderer.buildScene
  renderer.buildScene = function(self, ctx, proj)
    local ground, objects, scenes = baseBuildScene(self, ctx, proj)

    -- Every ground cell prefers a 16x16 texture rebuilt from its four runtime
    -- atlas tiles. Solid/object footprints receive a nearby walkable donor from
    -- the same atlas, so no tree/house pixels remain stamped flat underneath.
    for _, cmd in ipairs(ground or {}) do
      local originalRect = cmd.rect
      local map = cmd.scene and cmd.scene.map
      local cx, cy = cmd.cx, cmd.cy
      local tex
      if map and cx ~= nil and cy ~= nil then
        if cmd.material and cmd.material.kind == "solid" then
          local dx, dy = donorCell(self.MaterialClassifier, map, cx, cy)
          if dx ~= nil then
            tex = AtlasSource.cellTexture(self, map, dx, dy)
            if tex then
              self.lastAtlasDonorGroundCells =
                (self.lastAtlasDonorGroundCells or 0) + 1
            end
          end
        else
          tex = AtlasSource.cellTexture(self, map, cx, cy)
        end
      end

      if tex then
        cmd.rect = { 0, 0, CELL, CELL, atlasImage = tex }
        self.lastAtlasGroundCells = (self.lastAtlasGroundCells or 0) + 1
      elseif self._atlasDirectFrame then
        cmd.rect = nil
      else
        cmd.rect = originalRect
      end
    end

    for _, cmd in ipairs(objects or {}) do
      local map = cmd.scene and cmd.scene.map
      if map and (cmd.kind == "vegetation" or cmd.kind == "boundary"
                  or cmd.kind == "obstacle") then
        local cx, cy = localCell(cmd)
        if cx ~= nil and cy ~= nil then
          local tex = AtlasSource.cellTexture(self, map, cx, cy)
          if tex then
            cmd.atlasTexture = tex
            self.lastAtlasNaturalObjects =
              (self.lastAtlasNaturalObjects or 0) + 1
          end
        end
      elseif map and cmd.kind == "structure" and cmd.mass then
        local mass = cmd.mass
        local tex = AtlasSource.regionTexture(self, map,
                                               mass.minX, mass.minY,
                                               mass.maxX, mass.maxY)
        if tex then
          local ox = (tonumber(cmd.scene.ox) or 0) / CELL
          local oy = (tonumber(cmd.scene.oy) or 0) / CELL
          cmd.atlasStructureTexture = tex
          cmd.atlasStructureX = mass.minX + ox
          cmd.atlasStructureY = mass.minY + oy
          self.lastAtlasStructures = (self.lastAtlasStructures or 0) + 1
        end
      end
    end
    return ground, objects, scenes
  end

  local baseDrawTexturedQuad = renderer.drawTexturedQuad
  renderer.drawTexturedQuad = function(self, proj, x, y, z, rect, fallback)
    local result = drawAtlasQuad(self, proj, x, y, z, rect)
    if result ~= nil then return result end
    if self._atlasDirectFrame and rect ~= nil then
      self.lastFlatSourceFallbacks = (self.lastFlatSourceFallbacks or 0) + 1
      return baseDrawTexturedQuad(self, proj, x, y, z, nil, fallback)
    end
    return baseDrawTexturedQuad(self, proj, x, y, z, rect, fallback)
  end

  local baseDrawVegetation = renderer.drawVegetation
  renderer.drawVegetation = function(self, proj, cmd)
    if cmd and cmd.atlasTexture then
      return withTexture(self, cmd.atlasTexture, cmd.x, cmd.y, function()
        return baseDrawVegetation(self, proj, cmd)
      end)
    end
    if self._atlasDirectFrame then
      self.lastFlatSourceFallbacks = (self.lastFlatSourceFallbacks or 0) + 1
      return withoutFlatSource(self, function()
        return baseDrawVegetation(self, proj, cmd)
      end)
    end
    return baseDrawVegetation(self, proj, cmd)
  end

  local baseDrawLowPrism = renderer.drawLowPrism
  renderer.drawLowPrism = function(self, proj, cmd, height, topColor)
    if cmd and cmd.atlasTexture then
      return withTexture(self, cmd.atlasTexture, cmd.x, cmd.y, function()
        return baseDrawLowPrism(self, proj, cmd, height, topColor)
      end)
    end
    if self._atlasDirectFrame then
      self.lastFlatSourceFallbacks = (self.lastFlatSourceFallbacks or 0) + 1
      return withoutFlatSource(self, function()
        return baseDrawLowPrism(self, proj, cmd, height, topColor)
      end)
    end
    return baseDrawLowPrism(self, proj, cmd, height, topColor)
  end

  local baseDrawStructure = renderer.drawStructure
  renderer.drawStructure = function(self, proj, cmd)
    if cmd and cmd.atlasStructureTexture then
      return withTexture(self, cmd.atlasStructureTexture,
                         cmd.atlasStructureX, cmd.atlasStructureY, function()
        return baseDrawStructure(self, proj, cmd)
      end)
    end
    if self._atlasDirectFrame then
      self.lastFlatSourceFallbacks = (self.lastFlatSourceFallbacks or 0) + 1
      return withoutFlatSource(self, function()
        return baseDrawStructure(self, proj, cmd)
      end)
    end
    return baseDrawStructure(self, proj, cmd)
  end

  return renderer
end

return AtlasWorld
