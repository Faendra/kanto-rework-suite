local AtlasSource = {}

local CELL = 16
local TILE = 8

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
  local ok, a = pcall(map.tileAt, map, cx * 2,       cy * 2)
  local ok2, b = pcall(map.tileAt, map, cx * 2 + 1, cy * 2)
  local ok3, c = pcall(map.tileAt, map, cx * 2,       cy * 2 + 1)
  local ok4, d = pcall(map.tileAt, map, cx * 2 + 1,   cy * 2 + 1)
  if not (ok and ok2 and ok3 and ok4) then return nil end
  if a == nil or b == nil or c == nil or d == nil then return nil end
  return { a, b, c, d }
end

local function cacheKey(r, ids)
  return tostring(r.image) .. ":cell:"
      .. tostring(ids[1]) .. "," .. tostring(ids[2]) .. ","
      .. tostring(ids[3]) .. "," .. tostring(ids[4])
end

local function drawIds(r, ids, dx, dy)
  for ty = 0, 1 do
    for tx = 0, 1 do
      local id = ids[ty * 2 + tx + 1]
      local q = r.quads[id]
      if q then
        love.graphics.draw(r.image, q, dx + tx * TILE, dy + ty * TILE)
      end
    end
  end
end

local function regionSignature(r, map, x0, y0, x1, y1)
  local parts = { tostring(r.image), ":region:", tostring(x1 - x0 + 1), "x",
                  tostring(y1 - y0 + 1), ":" }
  for cy = y0, y1 do
    for cx = x0, x1 do
      local ids = idsFor(map, cx, cy)
      if not ids then return nil end
      parts[#parts + 1] = tostring(ids[1])
      parts[#parts + 1] = ","
      parts[#parts + 1] = tostring(ids[2])
      parts[#parts + 1] = ","
      parts[#parts + 1] = tostring(ids[3])
      parts[#parts + 1] = ","
      parts[#parts + 1] = tostring(ids[4])
      parts[#parts + 1] = ";"
    end
  end
  return table.concat(parts)
end

function AtlasSource.available(map)
  return rendererFor(map) ~= nil
     and love ~= nil and love.graphics ~= nil
     and type(love.graphics.newCanvas) == "function"
end

function AtlasSource.cellIds(map, cx, cy)
  return idsFor(map, cx, cy)
end

-- Exact single 8x8 runtime tile. This is intentionally separate from
-- cellTexture(): Gen I collision/ledge semantics are keyed by the bottom-left
-- tile of a 16x16 cell, so stretching the whole cell onto a vertical ledge face
-- mixes ground pixels into the cliff. The tile cache preserves the authored
-- pixel motif and whatever palette Gen1Recomp has already applied to its atlas.
function AtlasSource.tileTexture(host, map, tileId)
  local r = rendererFor(map)
  tileId = tonumber(tileId)
  if not r or tileId == nil or not AtlasSource.available(map) then return nil end
  local q = r.quads[tileId]
  if not q then return nil end

  host.atlasTileCache = host.atlasTileCache or {}
  local key = tostring(r.image) .. ":tile:" .. tostring(tileId)
  local cached = host.atlasTileCache[key]
  if cached then return cached end

  local canvas = love.graphics.newCanvas(TILE, TILE)
  if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(r.image, q, 0, 0)
  love.graphics.setCanvas()
  love.graphics.pop()

  host.atlasTileCache[key] = canvas
  host.lastAtlasTileTextures = (host.lastAtlasTileTextures or 0) + 1
  return canvas
end

function AtlasSource.cellTexture(host, map, cx, cy)
  local r = rendererFor(map)
  if not r or not AtlasSource.available(map) then return nil end
  local ids = idsFor(map, cx, cy)
  if not ids then return nil end

  host.atlasCellCache = host.atlasCellCache or {}
  local key = cacheKey(r, ids)
  local cached = host.atlasCellCache[key]
  if cached then return cached, ids end

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
  host.lastAtlasCellTextures = (host.lastAtlasCellTextures or 0) + 1
  return canvas, ids
end

function AtlasSource.regionTexture(host, map, x0, y0, x1, y1)
  local r = rendererFor(map)
  if not r or not AtlasSource.available(map) then return nil end
  x0, y0 = math.floor(x0), math.floor(y0)
  x1, y1 = math.floor(x1), math.floor(y1)
  if x1 < x0 or y1 < y0 then return nil end

  local key = regionSignature(r, map, x0, y0, x1, y1)
  if not key then return nil end
  host.atlasRegionCache = host.atlasRegionCache or {}
  local cached = host.atlasRegionCache[key]
  if cached then return cached end

  local w = (x1 - x0 + 1) * CELL
  local h = (y1 - y0 + 1) * CELL
  local canvas = love.graphics.newCanvas(w, h)
  if canvas.setFilter then canvas:setFilter("nearest", "nearest") end

  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  for cy = y0, y1 do
    for cx = x0, x1 do
      local ids = idsFor(map, cx, cy)
      if ids then
        drawIds(r, ids, (cx - x0) * CELL, (cy - y0) * CELL)
      end
    end
  end
  love.graphics.setCanvas()
  love.graphics.pop()

  host.atlasRegionCache[key] = canvas
  host.lastAtlasRegionTextures = (host.lastAtlasRegionTextures or 0) + 1
  return canvas
end

function AtlasSource.invalidate(host)
  if not host then return end
  for _, cache in ipairs({ host.atlasTileCache, host.atlasCellCache, host.atlasRegionCache }) do
    if cache then
      for _, canvas in pairs(cache) do safeRelease(canvas) end
    end
  end
  host.atlasTileCache = nil
  host.atlasCellCache = nil
  host.atlasRegionCache = nil
end

return AtlasSource
