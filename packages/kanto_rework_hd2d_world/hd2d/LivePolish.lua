local LivePolish = {}

local CELL = 16
local OUTDOOR = {
  OVERWORLD = true,
  FOREST = true,
  SHIP_PORT = true,
  PLATEAU = true,
}

-- Vanilla OVERWORLD semantic blocks. $0F is Gen1Recomp's own tree-wall
-- border fill. The remaining ids are the canonical cut-tree block variants
-- from pokered's data/tilesets/cut_tree_blocks.asm. This is tileset semantic
-- data, never map-specific authored geometry.
local OVERWORLD_TREE_BLOCKS = {
  [0x0F] = true,
  [0x32] = true, [0x33] = true, [0x34] = true, [0x35] = true,
  [0x60] = true, [0x0B] = true, [0x3C] = true, [0x3F] = true,
  [0x3D] = true,
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function mapTileset(map)
  return map and map.def and map.def.tileset or nil
end

local function safeBlockAt(map, cx, cy)
  if not map or type(map.blockAt) ~= "function" then return nil end
  local bx = math.floor(cx / 2)
  local by = math.floor(cy / 2)
  local ok, value = pcall(map.blockAt, map, bx, by)
  return ok and value or nil
end

local function installVanillaNaturalSemantics(classifier)
  if classifier.__livePolishNaturalSemantics then return end
  classifier.__livePolishNaturalSemantics = true
  local baseClassify = classifier.classify
  classifier.classify = function(map, cx, cy)
    local material = baseClassify(map, cx, cy)
    if material.kind ~= "solid" then return material end

    if mapTileset(map) == "OVERWORLD" then
      local block = safeBlockAt(map, cx, cy)
      if block ~= nil and OVERWORLD_TREE_BLOCKS[block] then
        material.family = "vegetation"
        material.heightScale = math.max(1.45, material.heightScale or 0)
      end
    end
    return material
  end
end

local function proxyProjection(proj, tileW, spriteScale)
  local override = {}
  if tileW then override.tileW = tileW end
  if spriteScale then override.spriteScale = spriteScale end
  return setmetatable(override, { __index = proj })
end

local function actorSurfaceZ(classifier, row)
  if not row or not row.map then return 0 end
  local cx = math.floor(((row.basePx or row.px or 0) + 8) / CELL)
  local cy = math.floor(((row.basePy or row.py or 0) + 12) / CELL)
  local material = classifier.classify(row.map, cx, cy)
  return material.kind == "water" and -0.12 or 0
end

local function apronColor(ctx, map, x, y)
  local r, g, b = 0.36, 0.53, 0.27
  local palette = ctx.paletteFor and ctx.paletteFor(map) or nil
  local c = type(palette) == "table" and (palette[2] or palette[1]) or nil
  if type(c) == "table" then
    local pr, pg, pb = tonumber(c[1]), tonumber(c[2]), tonumber(c[3])
    if pr and pg and pb then
      if pr > 1 or pg > 1 or pb > 1 then pr, pg, pb = pr / 255, pg / 255, pb / 255 end
      -- Keep the apron naturally green even when the current palette's light
      -- ground colour is nearly white.
      r = r * 0.72 + pr * 0.28
      g = g * 0.72 + pg * 0.28
      b = b * 0.72 + pb * 0.28
    end
  end
  local variation = ((x * 17 + y * 31) % 7 - 3) * 0.006
  return clamp(r + variation, 0, 1),
         clamp(g + variation, 0, 1),
         clamp(b + variation * 0.5, 0, 1)
end

local function drawOutdoorApron(renderer, ctx, proj)
  local state = ctx and ctx.state
  local map = state and state.map
  if not map or not OUTDOOR[mapTileset(map)] then return 0 end

  local w = tonumber(map.widthCells) or 0
  local h = tonumber(map.heightCells) or 0
  if w <= 0 or h <= 0 then return 0 end

  local radius = proj.visibleRadius and proj:visibleRadius() or 10
  local pad = math.min(12, math.max(7, math.ceil(radius * 0.72)))
  local drawn = 0
  love.graphics.push("all")
  for y = -pad, h + pad - 1 do
    for x = -pad, w + pad - 1 do
      if x < 0 or y < 0 or x >= w or y >= h then
        local r, g, b = apronColor(ctx, map, x, y)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.polygon("fill", proj:cellPolygon(x, y, -0.035))
        drawn = drawn + 1
      end
    end
  end
  love.graphics.pop()
  return drawn
end

local function boundaryHeight(cmd, originalHeight)
  local base = tonumber(originalHeight) or 0.14
  if base < 0.17 then return math.max(base, 0.15) end
  -- Edge/boundary masses are boulders or short retaining walls after vanilla
  -- tree blocks have already been promoted to vegetation. A small deterministic
  -- height variation breaks the continuous flat strip without inventing map
  -- profiles or changing collision.
  local x = math.floor(tonumber(cmd and cmd.x) or 0)
  local y = math.floor(tonumber(cmd and cmd.y) or 0)
  local step = ((x * 5 + y * 3) % 3) * 0.025
  return 0.235 + step
end

function LivePolish.apply(renderer)
  if not renderer or renderer.__livePolishApplied then return renderer end
  renderer.__livePolishApplied = true

  installVanillaNaturalSemantics(renderer.MaterialClassifier)

  local baseResetMetrics = renderer.resetMetrics
  renderer.resetMetrics = function(self)
    baseResetMetrics(self)
    self.lastApronCells = 0
    self.lastPerspectiveActors = 0
    self.lastPerspectiveVegetation = 0
    self.lastPerspectiveBoundaries = 0
  end

  local baseDrawBackdrop = renderer.drawBackdrop
  renderer.drawBackdrop = function(self, ctx, proj)
    baseDrawBackdrop(self, ctx, proj)
    self.lastApronCells = drawOutdoorApron(self, ctx, proj)
  end

  local baseDrawActor = renderer.drawActor
  renderer.drawActor = function(self, proj, row)
    local wx = ((row.basePx or row.px or 0) + (row.ox or 0) + 8) / CELL
    local wy = ((row.basePy or row.py or 0) + (row.oy or 0) + 12) / CELL
    local z = actorSurfaceZ(self.MaterialClassifier, row)
    local scale = proj.spriteScaleAt and proj:spriteScaleAt(wx, wy, z)
                  or proj.spriteScale
    if scale and scale > 0 then
      local ok = baseDrawActor(self, proxyProjection(proj, nil, scale), row)
      if ok then
        self.lastPerspectiveActors = (self.lastPerspectiveActors or 0) + 1
      end
      return ok
    end
    return baseDrawActor(self, proj, row)
  end

  local baseDrawVegetation = renderer.drawVegetation
  renderer.drawVegetation = function(self, proj, cmd)
    local cx, cy = cmd.x + 0.5, cmd.y + 0.5
    local localTile = proj.screenScale and proj:screenScale(cx, cy, 0)
                      or proj.tileW
    if localTile and localTile > 0 then
      self.lastPerspectiveVegetation = (self.lastPerspectiveVegetation or 0) + 1
      return baseDrawVegetation(self, proxyProjection(proj, localTile, nil), cmd)
    end
    return baseDrawVegetation(self, proj, cmd)
  end

  local baseDrawLowPrism = renderer.drawLowPrism
  renderer.drawLowPrism = function(self, proj, cmd, height, topColor)
    local cx, cy = (cmd.x or 0) + 0.5, (cmd.y or 0) + 0.5
    local localTile = proj.screenScale and proj:screenScale(cx, cy, 0)
                      or proj.tileW
    local h = boundaryHeight(cmd, height)
    if (tonumber(height) or 0) >= 0.17 then
      self.lastPerspectiveBoundaries = (self.lastPerspectiveBoundaries or 0) + 1
    end
    return baseDrawLowPrism(self, proxyProjection(proj, localTile, nil),
                            cmd, h, topColor)
  end

  local baseDrawStructure = renderer.drawStructure
  renderer.drawStructure = function(self, proj, cmd)
    local mass = cmd and cmd.mass
    if not mass then return baseDrawStructure(self, proj, cmd) end
    local ox = (cmd.scene and cmd.scene.ox or 0) / CELL
    local oy = (cmd.scene and cmd.scene.oy or 0) / CELL
    local cx = (mass.minX + mass.maxX + 1) * 0.5 + ox
    local cy = (mass.minY + mass.maxY + 1) * 0.5 + oy
    local localTile = proj.screenScale and proj:screenScale(cx, cy, 0)
                      or proj.tileW
    return baseDrawStructure(self, proxyProjection(proj, localTile, nil), cmd)
  end

  return renderer
end

return LivePolish
