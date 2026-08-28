local DepthComposer = {}
DepthComposer.__index = DepthComposer

local CELL = 16

function DepthComposer.new(Relief, Occlusion)
  return setmetatable({
    Relief = Relief,
    Occlusion = Occlusion,
    lastCommands = 0,
    lastTerrainRows = 0,
    lastActors = 0,
  }, DepthComposer)
end

local function actorMap(state, actor)
  for _, ghost in ipairs(state.ghosts or {}) do
    if ghost.npc == actor then
      return ghost.map, ghost.ox or 0, ghost.oy or 0
    end
  end
  return state.map, 0, 0
end

function DepthComposer:addScene(commands, map, ox, oy, ctx, proj)
  if not map then return end
  ox, oy = ox or 0, oy or 0
  local x0, y0, x1, y1 = self.Relief:visibleCellRange(map, proj, ox, oy)
  if x1 < x0 or y1 < y0 then return end

  self.Relief.lastScenes = self.Relief.lastScenes + 1
  for cy = y0, y1 do
    commands[#commands + 1] = {
      kind = "terrain",
      -- A raised row occludes an actor whose foot baseline lies north/behind
      -- its front edge. South/near actors are painted afterward.
      depth = (cy + 1) * CELL + oy,
      priority = 1,
      map = map,
      ox = ox,
      oy = oy,
      cy = cy,
      x0 = x0,
      x1 = x1,
    }
  end
end

function DepthComposer:addActors(commands, host, state)
  for _, row in ipairs(host:collectActors(state)) do
    local map, ox, oy = actorMap(state, row.actor)
    -- collectActors already carries ghost offsets. Prefer the authoritative
    -- ghost record when available, but keep those values for compatibility.
    row.ox = row.ox or ox
    row.oy = row.oy or oy
    row.map = map
    commands[#commands + 1] = {
      kind = "actor",
      depth = row.py + (row.oy or 0) + CELL,
      priority = 2,
      row = row,
    }
  end
end

function DepthComposer:drawActorOcclusion(proj, row)
  local actor = row.actor
  local map = row.map
  if not (actor and map) then return end
  local ox, oy = row.ox or 0, row.oy or 0

  self.Occlusion:drawOne(map, proj, actor, actor.cellX, actor.cellY, ox, oy)
  if actor.targetX ~= nil and actor.targetY ~= nil then
    self.Occlusion:drawOne(map, proj, actor,
                           actor.targetX, actor.targetY, ox, oy)
  end
end

function DepthComposer:draw(host, ctx, proj)
  local state = ctx and ctx.state
  if not (host and state and state.map and proj) then return 0 end

  self.Relief:resetMetrics()
  self.Occlusion:beginFrame()
  self.lastCommands, self.lastTerrainRows, self.lastActors = 0, 0, 0

  local commands = {}
  self:addScene(commands, state.map, 0, 0, ctx, proj)
  for _, nb in ipairs(state.neighbors or {}) do
    if nb.map then
      self:addScene(commands, nb.map, nb.ox or 0, nb.oy or 0, ctx, proj)
    end
  end
  self:addActors(commands, host, state)

  for i, command in ipairs(commands) do command.order = i end
  table.sort(commands, function(a, b)
    if a.depth ~= b.depth then return a.depth < b.depth end
    if a.priority ~= b.priority then return a.priority < b.priority end
    return a.order < b.order
  end)

  for _, command in ipairs(commands) do
    if command.kind == "terrain" then
      self.Relief:drawRow(host, ctx, proj,
                          command.map, command.ox, command.oy,
                          command.cy, command.x0, command.x1)
      self.lastTerrainRows = self.lastTerrainRows + 1
    else
      host:drawShadow(proj, command.row)
      host:drawActor(proj, command.row)
      -- Tall grass belongs to the same painter depth as its actor. Drawing it
      -- here prevents a far grass overlay from appearing over a nearer house.
      self:drawActorOcclusion(proj, command.row)
      self.lastActors = self.lastActors + 1
    end
  end

  self.lastCommands = #commands
  love.graphics.setColor(1, 1, 1, 1)
  return self.lastCommands
end

return DepthComposer
