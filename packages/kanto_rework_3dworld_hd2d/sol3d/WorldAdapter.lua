local WorldAdapter = {}
WorldAdapter.__index = WorldAdapter

function WorldAdapter.new(mod)
  return setmetatable({ mod = mod, lastError = nil }, WorldAdapter)
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

  self.lastError = nil
  return {
    mapId = current.mapId,
    player = {
      x = current.x,
      y = current.y,
      facing = current.facing,
    },
    overview = overview,
  }
end

return WorldAdapter
