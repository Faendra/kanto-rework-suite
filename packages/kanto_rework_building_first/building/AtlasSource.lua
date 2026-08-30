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

local function fillSignature(r, scenes, bounds)
  local parts = {
    tostring(r), tostring(r and r.image), tostring(r and r.quads),
    tostring(bounds.x0), tostring(bounds.y0), tostring(bounds.x1), tostring(bounds.y1),
  }
  for _, scene in ipairs(scenes or {}) do
    parts[#parts + 1] = table.concat({
      tostring(scene.map), tostring(scene.map and scene.map.id),
      tostring(scene.cx), tostring(scene.cy),
      tostring(scene.map and scene.map.widthCells), tostring(scene.map and scene.map.heightCells),
    }, ":")
  end
  return table.concat(parts, "|")
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

-- Build the engine's own world-aligned border/void fill once per connected
-- world generation. The map rectangles are then punched transparent so this
-- texture only occupies genuine outside-world gaps; semantic building masks
-- inside a map keep the same neutral underlay behavior as before instead of
-- exposing tree/water fill beneath a building.
function AtlasSource.worldFillTexture(host, primaryMap, scenes, bounds)
  local r = rendererFor(primaryMap)
  if not r or type(r.drawBorderFill) ~= "function" or not bounds then return nil end
  local w = math.max(1, math.floor((bounds.x1 - bounds.x0) * CELL))
  local h = math.max(1, math.floor((bounds.y1 - bounds.y0) * CELL))
  host.atlasFillCache = host.atlasFillCache or {}
  local key = fillSignature(r, scenes, bounds)
  if host.atlasFillCache[key] then return host.atlasFillCache[key] end

  local canvas = love.graphics.newCanvas(w, h)
  if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  r:drawBorderFill(bounds.x0 * CELL, bounds.y0 * CELL, w, h)

  if type(love.graphics.setBlendMode) == "function" then
    love.graphics.setBlendMode("replace")
  end
  love.graphics.setColor(0, 0, 0, 0)
  for _, scene in ipairs(scenes or {}) do
    local map = scene.map
    local x = (scene.cx - bounds.x0) * CELL
    local y = (scene.cy - bounds.y0) * CELL
    local mw = (tonumber(map and map.widthCells) or 0) * CELL
    local mh = (tonumber(map and map.heightCells) or 0) * CELL
    love.graphics.rectangle("fill", x, y, mw, mh)
  end
  love.graphics.setCanvas()
  love.graphics.pop()

  host.atlasFillCache[key] = canvas
  host.lastMaterialBuilds = (host.lastMaterialBuilds or 0) + 1
  return canvas
end

function AtlasSource.invalidate(host)
  if not host then return end
  local caches = { host.atlasCellCache, host.atlasRegionCache, host.atlasFillCache }
  local i
  for i = 1, #caches do
    local cache = caches[i]
    if cache then
      local _, canvas
      for _, canvas in pairs(cache) do safeRelease(canvas) end
    end
  end
  host.atlasCellCache, host.atlasRegionCache, host.atlasFillCache = nil, nil, nil
end

return AtlasSource
