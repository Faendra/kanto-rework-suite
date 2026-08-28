local NeighborScenes = require("sol3d.NeighborScenes")

local WorldAdapter = {}
WorldAdapter.__index = WorldAdapter

function WorldAdapter.new(mod)
  return setmetatable({ mod = mod, lastError = nil }, WorldAdapter)
end

local function contentGet(registry, id)
  if not (registry and type(registry.get) == "function") then return nil end
  local ok, value = pcall(registry.get, registry, id)
  if ok then return value end
  return nil
end

function WorldAdapter:snapshot()
  local current, currentErr = self.mod.world:current()
  if not current then
    self.lastError = currentErr or "no current world"
    return nil, self.lastError
  end

  local overview, overviewErr = self.mod.world:mapOverview()
  if not overview then
    self.lastError = overviewErr or "no map overview"
    return nil, self.lastError
  end

  -- Registry reads are public Mod API reads.  They are deliberately optional:
  -- if another engine version withholds one of these views, the renderer keeps
  -- its semantic overview path instead of reaching into Game.data.
  local mapDef = contentGet(self.mod.content and self.mod.content.maps,
                            current.mapId)
  local tilesetDef
  if mapDef and mapDef.tileset then
    tilesetDef = contentGet(self.mod.content and self.mod.content.tilesets,
                            mapDef.tileset)
  end

  -- Direct map connections are reconstructed as read-only preview scenes from
  -- the same public content registries.  They never become runtime Maps and do
  -- not own collision, scripts, objects, encounters or persistence.
  local neighbors = NeighborScenes.build(self.mod, mapDef)

  self.lastError = nil
  return {
    mapId = current.mapId,
    player = {
      x = current.x,
      y = current.y,
      facing = current.facing,
    },
    overview = overview,
    mapDef = mapDef,
    tilesetDef = tilesetDef,
    neighbors = neighbors,
  }
end

return WorldAdapter
