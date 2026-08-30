local AtlasSource = {}

local CELL = 16
local TILE = 8
local TREE_WALL_BLOCK = 0x0F

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
  local ty, tx
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
  local parts = { tostring(r.image), ":region:", tostring(x0), ",", tostring(y0), ":",
                  tostring(x1), ",", tostring(y1), ":" }
  local x, y
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

function AtlasSource.available(map)
  return rendererFor(map) ~= nil and love and love.graphics
     and type(love.graphics.newCanvas) == "function"
end

function AtlasSource.cellTexture(host, map, cx, cy)
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

function AtlasSource.regionTexture(host, map, x0, y0, x1, y1)
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
  local x, y
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

-- Material-only access to one vanilla 32x32 block.  WORLD-ENVELOPE-01 uses
-- the canonical OVERWORLD tree-wall block as foliage art, but the block's
-- pixels never determine geometry: WorldEnvelope authored the cluster
-- positions and BuildingRenderer authored the crossed cards.
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

function AtlasSource.treeWallTexture(host, map)
  return AtlasSource.blockTexture(host, map, TREE_WALL_BLOCK)
end

function AtlasSource.invalidate(host)
  if not host then return end
  local caches = {
    host.atlasCellCache,
    host.atlasRegionCache,
    host.atlasBlockCache,
  }
  for i = 1, #caches do
    local cache = caches[i]
    if cache then
      for _, canvas in pairs(cache) do safeRelease(canvas) end
    end
  end
  host.atlasCellCache, host.atlasRegionCache, host.atlasBlockCache = nil, nil, nil
end

AtlasSource.TREE_WALL_BLOCK = TREE_WALL_BLOCK

return AtlasSource
