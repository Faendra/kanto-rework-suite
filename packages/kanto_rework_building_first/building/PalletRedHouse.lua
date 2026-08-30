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

  -- The Gen1 drawing mixes roof depth and facade height in the same flat
  -- footprint. groundClaim removes the complete vanilla projection from the
  -- ground pass; footprint is the actual spatial depth used by the 3D model.
  -- The facade remains anchored on the canonical entrance row y=5.
  return {
    kind = "building",
    semantic = "HOUSE",
    family = "PALLET_HOUSE",
    id = "PALLET_RED_HOUSE",
    mapId = "PALLET_TOWN",
    groundClaim = { x0 = 4, y0 = 2, x1 = 8, y1 = 6 },
    footprint = { x0 = 4, y0 = 5, x1 = 8, y1 = 6 },
    door = { x = 5, y = 5, width = 1 },
    architecture = {
      wallHeight = 1.36,
      roofStyle = "hip",
      roofPeak = 2.34,
      roofThickness = 0.14,
      roofOverhang = 0.18,
      ridgeY = 5.5,
      ridgeInsetX = 1.0,
      doorHeight = 0.92,
      shadowInset = 0.04,
      -- The authored house roof occupies one 16px cell-row. Keep its lower
      -- quarter for the eave/fascia instead of stretching it over the slope.
      roofUV = { 0, 0, 1, 0, 1, 0.75, 0, 0.75 },
      fasciaUV = { 0, 0.75, 1, 0.75, 1, 1, 0, 1 },
      roofSideUV = { 0, 0, 1, 0, 1, 1, 0, 1 },
    },
    materials = {
      -- The old BUILDING-01 path used y=2..3 as one roof texture. The upper
      -- row is part of the flat projection around the building; the actual
      -- roof band is y=3. Split its striped hips from its central field.
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
