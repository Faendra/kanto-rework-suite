local PalletRedHouse = {}

local function destinationMap(warp)
  if type(warp) ~= "table" then return nil end
  local def = type(warp.def) == "table" and warp.def or warp
  return def.destMap
end

local function hasCanonicalDoor(map)
  if not map or type(map.warpAtCell) ~= "function" then return false end
  local ok, warp = pcall(map.warpAtCell, map, 5, 5)
  return ok and destinationMap(warp) == "REDS_HOUSE_1F"
end

function PalletRedHouse.detect(map)
  if not map or map.id ~= "PALLET_TOWN" or not hasCanonicalDoor(map) then
    return nil
  end

  -- ARCHITECTURE-VOLUME-01
  -- groundClaim is the complete vanilla projection removed from the flat map.
  -- architecture.footprint is independently authored, but for this house the
  -- observed projection depth is also occupied by the reconstructed building.
  -- Keeping those concepts separate prevents a future source-image change from
  -- silently redefining the 3D volume.
  local volume = { x0 = 4, y0 = 2, x1 = 8, y1 = 6 }
  local occlusion = { x0 = 3.82, y0 = 1.82, x1 = 8.18, y1 = 6.18 }

  return {
    kind = "building",
    semantic = "HOUSE",
    family = "PALLET_HOUSE",
    id = "PALLET_RED_HOUSE",
    mapId = "PALLET_TOWN",
    groundClaim = { x0 = 4, y0 = 2, x1 = 8, y1 = 6 },

    -- Compatibility alias consumed by the current generic renderer. It is
    -- intentionally the architectural footprint, never inferred from pixels.
    footprint = volume,
    gameplayFootprint = { x0 = 4, y0 = 2, x1 = 8, y1 = 6 },
    door = { x = 5, y = 5, width = 1 },

    architecture = {
      footprint = volume,
      width = 4.0,
      depth = 4.0,
      wallHeight = 1.36,
      roofStyle = "hip",
      roofPeak = 2.34,
      roofThickness = 0.14,
      roofOverhang = 0.18,
      -- Full-depth house: ridge is centered between rear y=2 and front y=6.
      ridgeY = 4.0,
      ridgeInsetX = 1.0,
      doorHeight = 0.92,
      shadowInset = 0.04,
      roofUV = { 0, 0, 1, 0, 1, 0.75, 0, 0.75 },
      fasciaUV = { 0, 0.75, 1, 0.75, 1, 1, 0, 1 },
      roofSideUV = { 0, 0, 1, 0, 1, 1, 0, 1 },
    },

    -- Visual occlusion is allowed to include the authored roof overhang. This
    -- metadata does not alter Gen1Recomp collision, warp or actor coordinates.
    occlusion = {
      footprint = occlusion,
      frontY = 6.18,
      rearY = 1.82,
    },

    materials = {
      roof = { x0 = 5, y0 = 3, x1 = 6, y1 = 3 },
      roofLeft = { x0 = 4, y0 = 3, x1 = 4, y1 = 3 },
      roofRight = { x0 = 7, y0 = 3, x1 = 7, y1 = 3 },
      facade = { x0 = 4, y0 = 4, x1 = 7, y1 = 5 },
      side = { x0 = 7, y0 = 4, x1 = 7, y1 = 5 },
      door = { x = 5, y = 5 },
    },
  }
end

return PalletRedHouse
