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

  -- Pokemon Red source ground truth:
  -- Pallet Town is 20x18 gameplay cells. Red's house is the left 2x2-block
  -- house and therefore spans cells x=4..7, y=2..5. Geometry is authored
  -- from this semantic footprint; the source pixels below are materials only.
  return {
    kind = "building",
    semantic = "HOUSE",
    id = "PALLET_RED_HOUSE",
    mapId = "PALLET_TOWN",
    footprint = { x0 = 4, y0 = 2, x1 = 8, y1 = 6 },
    door = { x = 5, y = 5, width = 1 },
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
      roof = { x0 = 4, y0 = 2, x1 = 7, y1 = 3 },
      facade = { x0 = 4, y0 = 4, x1 = 7, y1 = 5 },
      side = { x0 = 7, y0 = 4, x1 = 7, y1 = 5 },
      door = { x = 5, y = 5 },
    },
  }
end

return PalletRedHouse
