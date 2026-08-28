local NeighborScenes = {}

local function contentGet(registry, id)
  if not (registry and type(registry.get) == "function") then return nil end
  local ok, value = pcall(registry.get, registry, id)
  if ok then return value end
  return nil
end

local function asSet(list)
  local out = {}
  for _, value in ipairs(list or {}) do out[value] = true end
  return out
end

local function cellTile(mapDef, tilesetDef, cx, cy)
  if not (mapDef and tilesetDef and type(tilesetDef.blocks) == "table") then
    return nil
  end
  if cx < 0 or cy < 0 or cx >= mapDef.width * 2 or cy >= mapDef.height * 2 then
    return nil
  end

  -- Gen 1 walk cells are 16x16 px.  Each map block is 32x32 px / 4x4 tiles,
  -- and collision/material identity is read from the bottom-left 8x8 tile of
  -- the walk cell.  This is a read-only reconstruction from public registry
  -- data; it does not instantiate a second runtime Map.
  local tx, ty = cx * 2, cy * 2 + 1
  local bx, by = math.floor(tx / 4), math.floor(ty / 4)
  local blockId = mapDef.blocks and mapDef.blocks[by * mapDef.width + bx + 1]
  local block = blockId ~= nil and tilesetDef.blocks[blockId + 1] or nil
  if not block then return nil end
  return block[(ty % 4) * 4 + (tx % 4) + 1]
end

local function materialSets(mapDef, tilesetDef)
  local walkable = asSet(tilesetDef.walkable)

  -- Modern imported tilesets may expose these explicitly.  Keep the original
  -- Gen 1 water/shore ids only as a compatibility fallback so route seams do
  -- not become raised solid walls when the optional semantic lists are absent.
  local waterList = tilesetDef.waterTiles
  if waterList == nil then waterList = { 0x14 } end
  local shoreList = tilesetDef.shoreTiles
  if shoreList == nil and mapDef.tileset ~= "SHIP_PORT" then
    shoreList = { 0x32, 0x48 }
  end

  local water = asSet(waterList)
  for value in pairs(asSet(shoreList)) do water[value] = true end
  return walkable, water
end

local function warpSet(mapDef)
  local out = {}
  for _, warp in ipairs(mapDef.warps or {}) do
    if type(warp.x) == "number" and type(warp.y) == "number" then
      out[warp.y * 4096 + warp.x] = true
    end
  end
  return out
end

local function buildOverview(mapDef, tilesetDef)
  if not (mapDef and tilesetDef and type(mapDef.width) == "number"
      and type(mapDef.height) == "number" and type(mapDef.blocks) == "table") then
    return nil
  end

  local width, height = mapDef.width * 2, mapDef.height * 2
  local walkable, water = materialSets(mapDef, tilesetDef)
  local warps = warpSet(mapDef)
  local rows = {}

  for y = 0, height - 1 do
    local chars = {}
    for x = 0, width - 1 do
      local tile = cellTile(mapDef, tilesetDef, x, y)
      local key = y * 4096 + x
      if warps[key] then
        chars[#chars + 1] = "+"
      elseif tile ~= nil and water[tile] then
        chars[#chars + 1] = "~"
      elseif tile ~= nil and walkable[tile] then
        chars[#chars + 1] = "."
      else
        chars[#chars + 1] = " "
      end
    end
    rows[#rows + 1] = table.concat(chars)
  end

  return {
    width = width,
    height = height,
    rows = rows,
    -- Public registry data does not expose MapOverview's reduced raster.
    -- Neighbor previews therefore stay semantic rather than inventing detail.
    tileRows = nil,
    tileDetailRows = nil,
  }
end

local function placement(rootDef, destDef, direction, offsetBlocks)
  local offset = tonumber(offsetBlocks)
  if not offset then return nil end

  -- Convert the connection macro's 32 px block offset into the renderer's
  -- 16 px walk-cell coordinates.  Returned offsets place the neighbor in the
  -- active map's coordinate space.
  local ox, oy
  if direction == "north" then
    ox, oy = offset * 2, -destDef.height * 2
  elseif direction == "south" then
    ox, oy = offset * 2, rootDef.height * 2
  elseif direction == "west" then
    ox, oy = -destDef.width * 2, offset * 2
  elseif direction == "east" then
    ox, oy = rootDef.width * 2, offset * 2
  else
    return nil
  end
  return ox, oy
end

function NeighborScenes.build(mod, rootDef)
  local out = {}
  if not (mod and mod.content and rootDef and type(rootDef.connections) == "table") then
    return out
  end

  local maps = mod.content.maps
  local tilesets = mod.content.tilesets
  local seen = {}

  for direction, conn in pairs(rootDef.connections) do
    local mapId = type(conn) == "table" and conn.map or nil
    if type(mapId) == "string" and not seen[mapId] then
      local mapDef = contentGet(maps, mapId)
      local tilesetDef = mapDef and contentGet(tilesets, mapDef.tileset) or nil
      local overview = mapDef and tilesetDef and buildOverview(mapDef, tilesetDef) or nil
      local ox, oy = mapDef and placement(rootDef, mapDef, direction, conn.offset)
      if overview and ox and oy then
        seen[mapId] = true
        out[#out + 1] = {
          mapId = mapId,
          direction = direction,
          offsetX = ox,
          offsetY = oy,
          overview = overview,
          mapDef = mapDef,
          tilesetDef = tilesetDef,
          preview = true,
        }
      end
    end
  end

  table.sort(out, function(a, b)
    if a.direction ~= b.direction then return a.direction < b.direction end
    return a.mapId < b.mapId
  end)
  return out
end

return NeighborScenes
