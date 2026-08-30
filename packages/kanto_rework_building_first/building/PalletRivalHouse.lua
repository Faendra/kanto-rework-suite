local PalletRivalHouse = {}

local function destinationMap(warp)
  if type(warp) ~= "table" then return nil end
  local def = type(warp.def) == "table" and warp.def or warp
  return def.destMap
end

local function hasCanonicalDoor(map)
  if not map or type(map.warpAtCell) ~= "function" then return false end
  local ok, warp = pcall(map.warpAtCell, map, 13, 5)
  return ok and destinationMap(warp) == "BLUES_HOUSE"
end

function PalletRivalHouse.detect(map)
  if not map or map.id ~= "PALLET_TOWN" or not hasCanonicalDoor(map) then
    return nil
  end

  local volume = { x0 = 12, y0 = 2, x1 = 16, y1 = 6 }
  local occlusion = { x0 = 11.82, y0 = 1.82, x1 = 16.18, y1 = 6.18 }

  return {
    kind = "building",
    semantic = "HOUSE",
    family = "PALLET_HOUSE",
    id = "PALLET_RIVAL_HOUSE",
    mapId = "PALLET_TOWN",
    groundClaim = { x0 = 12, y0 = 2, x1 = 16, y1 = 6 },
    footprint = volume,
    gameplayFootprint = { x0 = 12, y0 = 2, x1 = 16, y1 = 6 },
    door = { x = 13, y = 5, width = 1 },

    architecture = {
      footprint = volume,
      width = 4.0,
      depth = 4.0,
      wallHeight = 1.36,
      roofStyle = "hip",
      roofPeak = 2.34,
      roofThickness = 0.14,
      roofOverhang = 0.18,
      ridgeY = 4.0,
      ridgeInsetX = 1.0,
      doorHeight = 0.92,
      shadowInset = 0.04,
      roofUV = { 0, 0, 1, 0, 1, 0.75, 0, 0.75 },
      fasciaUV = { 0, 0.75, 1, 0.75, 1, 1, 0, 1 },
      roofSideUV = { 0, 0, 1, 0, 1, 1, 0, 1 },
    },

    occlusion = {
      footprint = occlusion,
      frontY = 6.18,
      rearY = 1.82,
    },

    materials = {
      roof = { x0 = 13, y0 = 3, x1 = 14, y1 = 3 },
      roofLeft = { x0 = 12, y0 = 3, x1 = 12, y1 = 3 },
      roofRight = { x0 = 15, y0 = 3, x1 = 15, y1 = 3 },
      facade = { x0 = 12, y0 = 4, x1 = 15, y1 = 5 },
      side = { x0 = 15, y0 = 4, x1 = 15, y1 = 5 },
      door = { x = 13, y = 5 },
    },
  }
end

return PalletRivalHouse
