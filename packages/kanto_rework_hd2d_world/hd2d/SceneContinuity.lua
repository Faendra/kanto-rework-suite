local SceneContinuity = {}

local CELL = 16

local function key(x, y)
  return tostring(math.floor(x)) .. ":" .. tostring(math.floor(y))
end

local function actorCell(row)
  local wx = ((row.basePx or row.px or 0) + (row.ox or 0) + 8) / CELL
  local wy = ((row.basePy or row.py or 0) + (row.oy or 0) + 12) / CELL
  return wx, wy
end

local function hasSupport(support, wx, wy)
  local x, y = math.floor(wx), math.floor(wy)
  if support[key(x, y)] then return true end
  -- Keep seam movement tolerant to one-cell animation offsets without allowing
  -- an entity to float many cells beyond the rendered connected map.
  return support[key(x + 1, y)] or support[key(x - 1, y)]
      or support[key(x, y + 1)] or support[key(x, y - 1)]
end

function SceneContinuity.apply(renderer)
  if not renderer or renderer.__sceneContinuityApplied then return renderer end
  renderer.__sceneContinuityApplied = true

  local baseResetMetrics = renderer.resetMetrics
  renderer.resetMetrics = function(self)
    baseResetMetrics(self)
    self.lastCulledUnsupportedActors = 0
  end

  local baseBuildScene = renderer.buildScene
  renderer.buildScene = function(self, ctx, proj)
    local ground, objects, scenes = baseBuildScene(self, ctx, proj)
    local support = {}
    for _, row in ipairs(ground or {}) do
      support[key(row.x or 0, row.y or 0)] = true
    end

    local filtered = {}
    local player = ctx and ctx.state and ctx.state.player
    for _, row in ipairs(objects or {}) do
      if row.kind ~= "actor" or row.actor == player then
        filtered[#filtered + 1] = row
      else
        local wx, wy = actorCell(row)
        if hasSupport(support, wx, wy) then
          filtered[#filtered + 1] = row
        else
          self.lastCulledUnsupportedActors =
            (self.lastCulledUnsupportedActors or 0) + 1
        end
      end
    end
    return ground, filtered, scenes
  end

  return renderer
end

return SceneContinuity
