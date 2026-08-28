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
  local ok, a = pcall(map.tileAt, map, cx * 2,     cy * 2)
  local ok2, b = pcall(map.tileAt, map, cx * 2 + 1, cy * 2)
  local ok3, c = pcall(map.tileAt, map, cx * 2,     cy * 2 + 1)
  local ok4, d = pcall(map.tileAt, map, cx * 2 + 1, cy * 2 + 1)
  if not (ok and ok2 and ok3 and ok4) then return nil end
  if a == nil or b == nil or c == nil or d == nil then return nil end
  return { a, b, c, d }
end

local function cacheKey(r, ids)
  return tostring(r.image) .. ":"
      .. tostring(ids[1]) .. "," .. tostring(ids[2]) .. ","
      .. tostring(ids[3]) .. "," .. tostring(ids[4])
end

function AtlasSource.available(map)
  return rendererFor(map) ~= nil
     and love ~= nil and love.graphics ~= nil
     and type(love.graphics.newCanvas) == "function"
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
  for ty = 0, 1 do
    for tx = 0, 1 do
      local id = ids[ty * 2 + tx + 1]
      local q = r.quads[id]
      if q then
        love.graphics.draw(r.image, q, tx * TILE, ty * TILE)
      end
    end
  end
  love.graphics.setCanvas()
  love.graphics.pop()

  host.atlasCellCache[key] = canvas
  host.lastAtlasCellTextures = (host.lastAtlasCellTextures or 0) + 1
  return canvas, ids
end

function AtlasSource.invalidate(host)
  if not host or not host.atlasCellCache then return end
  for _, canvas in pairs(host.atlasCellCache) do safeRelease(canvas) end
  host.atlasCellCache = nil
end

return AtlasSource
