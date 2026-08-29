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

  -- Pokemon Red source ground truth:
  -- PalletTown.blk uses the same 2x2 block house motif for the rival's house
  -- at blocks x=6..7, y=1..2. That maps to gameplay cells x=12..15,
  -- y=2..5, with the canonical BLUES_HOUSE warp at cell (13,5).
  return {
    kind = "building",
    semantic = "HOUSE",
    family = "PALLET_HOUSE",
    id = "PALLET_RIVAL_HOUSE",
    mapId = "PALLET_TOWN",
    footprint = { x0 = 12, y0 = 2, x1 = 16, y1 = 6 },
    door = { x = 13, y = 5, width = 1 },
    architecture = {
      wallHeight = 1.36,
      roofPeak = 2.34,
      roofThickness = 0.14,
      roofOverhang = 0.18,
      ridgeY = 4.0,
      doorHeight = 0.92,
      shadowInset = 0.04,
    },
    materials = {
      roof = { x0 = 12, y0 = 2, x1 = 15, y1 = 3 },
      facade = { x0 = 12, y0 = 4, x1 = 15, y1 = 5 },
      side = { x0 = 15, y0 = 4, x1 = 15, y1 = 5 },
      door = { x = 13, y = 5 },
    },
  }
end

return PalletRivalHouse
