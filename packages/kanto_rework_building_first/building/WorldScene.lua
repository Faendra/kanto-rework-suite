local WorldScene = {}

local CELL = 16
local DEFAULT_FILL_PAD = 24

local function mapRenderer(map)
  return map and map.renderer or nil
end

local function addScene(out, map, ox, oy, primary)
  if not map then return end
  out[#out + 1] = {
    map = map,
    ox = tonumber(ox) or 0,
    oy = tonumber(oy) or 0,
    cx = (tonumber(ox) or 0) / CELL,
    cy = (tonumber(oy) or 0) / CELL,
    primary = primary == true,
  }
end

function WorldScene.collect(state)
  local out = {}
  if not state then return out end
  addScene(out, state.map, 0, 0, true)
  for _, nb in ipairs(state.neighbors or {}) do
    if nb and nb.map then addScene(out, nb.map, nb.ox, nb.oy, false) end
  end
  return out
end

-- Cheap identity used by the renderer's resource-generation gate. Connected
-- map objects and their atlas backing can be replaced while the primary map
-- object survives, so the neighbor set belongs to GPU resource identity too.
function WorldScene.identity(state)
  local parts = {}
  for _, scene in ipairs(WorldScene.collect(state)) do
    local r = mapRenderer(scene.map)
    parts[#parts + 1] = table.concat({
      tostring(scene.map), tostring(scene.map and scene.map.id),
      tostring(r), tostring(r and r.image), tostring(r and r.quads),
      tostring(scene.ox), tostring(scene.oy),
    }, ":")
  end
  return table.concat(parts, "|")
end

function WorldScene.bounds(scenes, pad)
  pad = tonumber(pad) or DEFAULT_FILL_PAD
  local minX, minY, maxX, maxY
  for _, scene in ipairs(scenes or {}) do
    local map = scene.map
    local x0, y0 = scene.cx, scene.cy
    local x1 = x0 + (tonumber(map and map.widthCells) or 0)
    local y1 = y0 + (tonumber(map and map.heightCells) or 0)
    minX = minX and math.min(minX, x0) or x0
    minY = minY and math.min(minY, y0) or y0
    maxX = maxX and math.max(maxX, x1) or x1
    maxY = maxY and math.max(maxY, y1) or y1
  end
  if not minX then return nil end
  return {
    x0 = math.floor(minX - pad),
    y0 = math.floor(minY - pad),
    x1 = math.ceil(maxX + pad),
    y1 = math.ceil(maxY + pad),
  }
end

WorldScene.CELL = CELL
WorldScene.DEFAULT_FILL_PAD = DEFAULT_FILL_PAD

return WorldScene
