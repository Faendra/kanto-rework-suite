local AtlasSource = {}

local CELL = 16
local TILE = 8
local TREE_WALL_BLOCK = 0x0F

-- VISUAL-SKIN-FIRERED-01
-- Compact semantic atlas reconstructed from the user-provided FireRed/LeafGreen
-- tileset. Only the Pallet house material fragments required by this prototype
-- are embedded; Gen1Recomp remains authoritative for world/gameplay data.
local FIRERED_PREFIX = "FIRERED:"
local FIRERED_ATLAS_B64 = [[iVBORw0KGgoAAAANSUhEUgAAAIAAAABACAYAAADS1n9/AAAEV0lEQVR42u1dK5izOhA9ez9EJRKJRCKRyJWVKysrKyuRSCSysrKyEomMREZGIuv6i5bd7N7yagg0zRy1LcnkMZPkzEzofpwFu+KOIjthDsS79WSyDrsDDjsPAMAPFfxN8P2s+Xz6OuAUfcIUiPoCAEhXHJxx+KH/Mybp8/7iozjnHyptObLiNzWHG7jaBsaLCpxxpEzcBnDYap3IpHaBTGANYF2eYRr2QQwEPlJwbW04RXZCsl7dV8w8A0tXtwHtN/m3EYRuAFZXv8oV2QklE1hnawSuN1j+JrsZmKz0PIiNUv62KrCtih9DkOZtUgNolL8E0hVHff9bVr68I4VViXyHXzsGEwKh57Wv+AeKj0LPKAPIET82hIl3BKdru54Sfhz0lmkU/3dHkneMR0dH14o3TfENmn63GoJuAwAA15tn8uQVL5O4RzsGZxzp5veO0Kb48s41TEcUeg8NYYpjzVFZsVMpfywHkXcEz111rngvCM3WPju37ghT4D/TV4eoL8Zv908dDRMdA47pEyL7wcX54XOYP8aOmMrn9vqs4ZdMmG8AhDtp5/U4Uu6777EDEIBYlDggAPeHBdZ8niMWJUr487iBcxFK2xHcV3UfLhyI4gg4Cv1uYC0EaeaFod0N1JlbIPz1EIZFdYvijdxAguVuIEFa2VlCBmAjDpfbcZ1/umQANiLPU5SMY5vnSMILGYBtKBn/cd8rPsZBpzjAWxwB+S3cvVmN1xnFAd4Azyie4gBvhFT45AbaDJVsIAWCLFV+U9cBIN2bd4FSY29XARAFf3hoN+LdZ+vRdATgne02gDRN1N4L2Cx8b575X7SMF4TTKH6pe/MR6WBZA3j1+3RTX08n/DGAV79IOdfVdGsN4NU7SHEEzQaw9L15UTHSwoKgOIDl+Cgrce0rtN8lenzY+wUG3fK7cKzPWJ04SiZwOmaoRP39rCxLRFH01vUHcwD/a9fP2I/Z6LJzySe0GADnfDkXT3Pbg+S7ijIMr+/4vj+5Oza0rNy2bvltKOtKSYbp9YkEUhxgGAKv/845e6LsXPIJxAGIA6hwgJD3M+/jyLJy27rlEwdQPAL2I16z3z/xSr5u+QQFAzhp8qmboIVu+QRFDqCbJixIQ6znAOQGWg4yANuPAFZYfqty3c2Se+fH8PrOerO1Wv/HunuC+ubH9Pq9XoBqqjbNEhAMdwN1K7/LyMIkUsp3ExQNQM6968zHt8ssSUvLxgFcBf9ev4Ov3IblcYDeXICL/2fepszHj5Wp0sbD/YXuAxCIA3RAzr2zB9+1+p8jO9Ims7qQkpblAF5IHMBmDoDqh53ryMejR2blRcQBNNbvDwTlw75TRZvMMAFhSQ6gkqsfmo/vaiOpjqSlJTnAHLn6zjbc3wYl91dUDFz17WFV+YbXJzfQcpABWI6P/T65vnIHL2v/Oxmk48csVOWbXt959X+uGEoXHnT0VVW+6fVf/idimkCgrn6qyje9/j9qXMiRgpP8kQAAAABJRU5ErkJggg==]]

local FIRERED_REGIONS = {
  roof = { x = 0, y = 0, w = 32, h = 32 },
  roofLeft = { x = 32, y = 0, w = 8, h = 32 },
  roofRight = { x = 40, y = 0, w = 8, h = 32 },
  fascia = { x = 48, y = 0, w = 64, h = 8 },
  facade = { x = 0, y = 32, w = 64, h = 32 },
  side = { x = 64, y = 32, w = 64, h = 32 },
  door = { x = 112, y = 8, w = 16, h = 16 },
}

local function safeRelease(obj)
  if obj and obj.release then pcall(obj.release, obj) end
end

local function rendererFor(map)
  local r = map and map.renderer
  if not (r and r.image and r.quads) then return nil end
  if type(map.tileAt) ~= "function" then return nil end
  return r
end

local function idsFor(map, cx, cy)
  local ok1, a = pcall(map.tileAt, map, cx * 2, cy * 2)
  local ok2, b = pcall(map.tileAt, map, cx * 2 + 1, cy * 2)
  local ok3, c = pcall(map.tileAt, map, cx * 2, cy * 2 + 1)
  local ok4, d = pcall(map.tileAt, map, cx * 2 + 1, cy * 2 + 1)
  if not (ok1 and ok2 and ok3 and ok4) then return nil end
  if a == nil or b == nil or c == nil or d == nil then return nil end
  return { a, b, c, d }
end

local function drawIds(r, ids, dx, dy)
  for ty = 0, 1 do
    for tx = 0, 1 do
      local q = r.quads[ids[ty * 2 + tx + 1]]
      if q then love.graphics.draw(r.image, q, dx + tx * TILE, dy + ty * TILE) end
    end
  end
end

local function cellSignature(r, ids)
  return tostring(r.image) .. ":cell:" .. table.concat(ids, ",")
end

local function regionSignature(r, map, x0, y0, x1, y1)
  local parts = {
    tostring(r.image), ":region:", tostring(x0), ",", tostring(y0), ":",
    tostring(x1), ",", tostring(y1), ":",
  }
  for y = y0, y1 do
    for x = x0, x1 do
      local ids = idsFor(map, x, y)
      if not ids then return nil end
      parts[#parts + 1] = table.concat(ids, ",")
      parts[#parts + 1] = ";"
    end
  end
  return table.concat(parts)
end

local function groundSignature(r, map, ground)
  local h = 17
  for i = 1, #(ground or {}) do
    local c = ground[i]
    h = (h * 131 + (tonumber(c.x) or 0) * 17 + (tonumber(c.y) or 0) * 31) % 2147483647
  end
  return table.concat({
    tostring(r.image), ":ground:", tostring(map), ":",
    tostring(map and map.widthCells), "x", tostring(map and map.heightCells), ":",
    tostring(#(ground or {})), ":", tostring(h),
  })
end

local function tilesetFor(map, r)
  return (map and map.tileset) or (r and r.map and r.map.tileset) or nil
end

local function blockFor(map, r, blockId)
  local tileset = tilesetFor(map, r)
  local blocks = tileset and tileset.blocks
  return blocks and blocks[blockId + 1] or nil
end

local function blockSignature(r, blockId, block)
  local parts = { tostring(r.image), ":block:", tostring(blockId), ":" }
  for i = 1, #block do
    parts[#parts + 1] = tostring(block[i])
    parts[#parts + 1] = ","
  end
  return table.concat(parts)
end

local function fireRedKey(value)
  if type(value) ~= "string" then return nil end
  if value:sub(1, #FIRERED_PREFIX) ~= FIRERED_PREFIX then return nil end
  return value:sub(#FIRERED_PREFIX + 1)
end

local function fireRedAvailable()
  return love and love.data and love.filesystem and love.graphics
     and type(love.data.decode) == "function"
     and type(love.filesystem.newFileData) == "function"
     and type(love.graphics.newImage) == "function"
     and type(love.graphics.newCanvas) == "function"
     and type(love.graphics.newQuad) == "function"
end

local function fireRedAtlas(host)
  if not fireRedAvailable() then return nil end
  host.fireRedSkinCache = host.fireRedSkinCache or { textures = {} }
  local cache = host.fireRedSkinCache
  if cache.atlas then return cache.atlas end

  local okDecode, bytes = pcall(love.data.decode, "string", "base64", FIRERED_ATLAS_B64)
  if not okDecode or not bytes then return nil end
  local okFile, fileData = pcall(love.filesystem.newFileData, bytes, "firered_pallet_house_skin.png")
  if not okFile or not fileData then return nil end
  local okImage, image = pcall(love.graphics.newImage, fileData)
  if not okImage or not image then return nil end
  if image.setFilter then image:setFilter("nearest", "nearest") end
  cache.atlas = image
  host.lastMaterialBuilds = (host.lastMaterialBuilds or 0) + 1
  return image
end

local function fireRedTexture(host, key)
  local region = FIRERED_REGIONS[key]
  if not region then return nil end
  host.fireRedSkinCache = host.fireRedSkinCache or { textures = {} }
  local cache = host.fireRedSkinCache
  cache.textures = cache.textures or {}
  if cache.textures[key] then return cache.textures[key] end

  local image = fireRedAtlas(host)
  if not image then return nil end
  local canvas = love.graphics.newCanvas(region.w, region.h)
  if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
  if canvas.setWrap then pcall(canvas.setWrap, canvas, "repeat", "clamp") end
  local quad = love.graphics.newQuad(region.x, region.y, region.w, region.h, 128, 64)

  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(image, quad, 0, 0)
  love.graphics.setCanvas()
  love.graphics.pop()

  cache.textures[key] = canvas
  host.lastMaterialBuilds = (host.lastMaterialBuilds or 0) + 1
  return canvas
end

function AtlasSource.available(map)
  return rendererFor(map) ~= nil and love and love.graphics
     and type(love.graphics.newCanvas) == "function"
end

function AtlasSource.cellTexture(host, map, cx, cy)
  local skinKey = fireRedKey(cx)
  if skinKey then return fireRedTexture(host, skinKey) end

  local r = rendererFor(map)
  if not r or not AtlasSource.available(map) then return nil end
  local ids = idsFor(map, cx, cy)
  if not ids then return nil end
  host.atlasCellCache = host.atlasCellCache or {}
  local key = cellSignature(r, ids)
  if host.atlasCellCache[key] then return host.atlasCellCache[key] end

  local canvas = love.graphics.newCanvas(CELL, CELL)
  if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  drawIds(r, ids, 0, 0)
  love.graphics.setCanvas()
  love.graphics.pop()
  host.atlasCellCache[key] = canvas
  host.lastMaterialBuilds = (host.lastMaterialBuilds or 0) + 1
  return canvas
end

-- Compose one transparent whole-map material from the semantic ground cells.
-- Building source rectangles remain transparent. Geometry is still tessellated
-- later by BuildingRenderer, so perspective remains correct at cell boundaries
-- while the GPU sees one texture/draw call per map instead of one per cell.
function AtlasSource.groundSurfaceTexture(host, map, ground)
  local r = rendererFor(map)
  if not r or not AtlasSource.available(map) then return nil end
  local wCells = math.max(0, math.floor(tonumber(map and map.widthCells) or 0))
  local hCells = math.max(0, math.floor(tonumber(map and map.heightCells) or 0))
  if wCells <= 0 or hCells <= 0 then return nil end

  host.atlasGroundCache = host.atlasGroundCache or {}
  local key = groundSignature(r, map, ground)
  if host.atlasGroundCache[key] then return host.atlasGroundCache[key] end

  local canvas = love.graphics.newCanvas(wCells * CELL, hCells * CELL)
  if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)

  for i = 1, #(ground or {}) do
    local c = ground[i]
    local ids = idsFor(map, c.x, c.y)
    if ids then drawIds(r, ids, c.x * CELL, c.y * CELL) end
  end

  love.graphics.setCanvas()
  love.graphics.pop()
  host.atlasGroundCache[key] = canvas
  host.lastMaterialBuilds = (host.lastMaterialBuilds or 0) + 1
  return canvas
end

function AtlasSource.regionTexture(host, map, x0, y0, x1, y1)
  local skinKey = fireRedKey(x0)
  if skinKey then return fireRedTexture(host, skinKey) end

  local r = rendererFor(map)
  if not r or not AtlasSource.available(map) then return nil end
  local key = regionSignature(r, map, x0, y0, x1, y1)
  if not key then return nil end
  host.atlasRegionCache = host.atlasRegionCache or {}
  if host.atlasRegionCache[key] then return host.atlasRegionCache[key] end

  local w, h = (x1 - x0 + 1) * CELL, (y1 - y0 + 1) * CELL
  local canvas = love.graphics.newCanvas(w, h)
  if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  for y = y0, y1 do
    for x = x0, x1 do
      local ids = idsFor(map, x, y)
      if ids then drawIds(r, ids, (x - x0) * CELL, (y - y0) * CELL) end
    end
  end
  love.graphics.setCanvas()
  love.graphics.pop()
  host.atlasRegionCache[key] = canvas
  host.lastMaterialBuilds = (host.lastMaterialBuilds or 0) + 1
  return canvas
end

function AtlasSource.blockTexture(host, map, blockId)
  local r = rendererFor(map)
  if not r or not AtlasSource.available(map) then return nil end
  local block = blockFor(map, r, blockId)
  if not block or #block < 16 then return nil end
  host.atlasBlockCache = host.atlasBlockCache or {}
  local key = blockSignature(r, blockId, block)
  if host.atlasBlockCache[key] then return host.atlasBlockCache[key] end

  local canvas = love.graphics.newCanvas(32, 32)
  if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  for ty = 0, 3 do
    for tx = 0, 3 do
      local tile = block[ty * 4 + tx + 1]
      local q = r.quads[tile]
      if q then love.graphics.draw(r.image, q, tx * TILE, ty * TILE) end
    end
  end
  love.graphics.setCanvas()
  love.graphics.pop()
  host.atlasBlockCache[key] = canvas
  host.lastMaterialBuilds = (host.lastMaterialBuilds or 0) + 1
  return canvas
end

-- OVERWORLD block $0F is a 32x32 wall containing four repeated 16x16 tree
-- canopies. The envelope needs one semantic tree, not the whole wall, so crop
-- the top-left 2x2 tile quadrant into its own cached material. Pixels remain a
-- material source only; WorldEnvelope still authors every tree position.
function AtlasSource.treeWallTexture(host, map)
  local r = rendererFor(map)
  if not r or not AtlasSource.available(map) then return nil end
  local block = blockFor(map, r, TREE_WALL_BLOCK)
  if not block or #block < 16 then return nil end
  local ids = { block[1], block[2], block[5], block[6] }
  host.atlasBlockCache = host.atlasBlockCache or {}
  local key = tostring(r.image) .. ":tree-canopy:" .. table.concat(ids, ",")
  if host.atlasBlockCache[key] then return host.atlasBlockCache[key] end

  local canvas = love.graphics.newCanvas(CELL, CELL)
  if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  drawIds(r, ids, 0, 0)
  love.graphics.setCanvas()
  love.graphics.pop()
  host.atlasBlockCache[key] = canvas
  host.lastMaterialBuilds = (host.lastMaterialBuilds or 0) + 1
  return canvas
end

function AtlasSource.invalidate(host)
  if not host then return end
  local caches = {
    host.atlasCellCache,
    host.atlasGroundCache,
    host.atlasRegionCache,
    host.atlasBlockCache,
  }
  for i = 1, #caches do
    local cache = caches[i]
    if cache then
      for _, canvas in pairs(cache) do safeRelease(canvas) end
    end
  end

  local skin = host.fireRedSkinCache
  if skin then
    for _, texture in pairs(skin.textures or {}) do safeRelease(texture) end
    safeRelease(skin.atlas)
  end

  host.atlasCellCache = nil
  host.atlasGroundCache = nil
  host.atlasRegionCache = nil
  host.atlasBlockCache = nil
  host.fireRedSkinCache = nil
end

AtlasSource.TREE_WALL_BLOCK = TREE_WALL_BLOCK
AtlasSource.FIRERED_PREFIX = FIRERED_PREFIX
AtlasSource.FIRERED_REGIONS = FIRERED_REGIONS

return AtlasSource
