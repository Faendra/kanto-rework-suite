local CameraContinuity = {}

-- Preserve the same world-space camera point when an edge connection re-roots
-- coordinates onto the destination map.  Ordinary warps intentionally keep
-- the renderer's existing snap behaviour.
function CameraContinuity.prepare(renderer, adapter, mod)
  if not (renderer and adapter and mod and mod.world) then return false end
  local oldMapId = renderer.lastMapId
  if not (oldMapId and renderer.cameraX and renderer.cameraY) then return false end

  local current = mod.world:current()
  if not current or not current.mapId or current.mapId == oldMapId then
    return false
  end

  local snapshot = adapter:snapshot()
  if not snapshot or snapshot.mapId ~= current.mapId then return false end

  for _, neighbor in ipairs(snapshot.neighbors or {}) do
    if neighbor.mapId == oldMapId then
      renderer.cameraX = renderer.cameraX + (neighbor.offsetX or 0)
      renderer.cameraY = renderer.cameraY + (neighbor.offsetY or 0)
      -- Mark the new root before Renderer:drawWorld.  That prevents its
      -- generic map-change safety snap; drawWorld will immediately replace
      -- targetCameraX/Y with the destination player's live pose.
      renderer.lastMapId = snapshot.mapId
      return true
    end
  end

  -- No direct connection proves a shared coordinate frame.  Leave lastMapId
  -- untouched so Renderer:drawWorld snaps on a door/teleport/fly/script warp.
  return false
end

return CameraContinuity
