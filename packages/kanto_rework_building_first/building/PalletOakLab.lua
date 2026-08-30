local PalletOakLab = {}

local function destinationMap(warp)
  if type(warp) ~= "table" then return nil end
  local def = type(warp.def) == "table" and warp.def or warp
  return def.destMap
end

local function hasCanonicalDoor(map)
  if not map or type(map.warpAtCell) ~= "function" then return false end
  local ok, warp = pcall(map.warpAtCell, map, 12, 11)
  return ok and destinationMap(warp) == "OAKS_LAB"
end

function PalletOakLab.detect(map)
  if not map or map.id ~= "PALLET_TOWN" or not hasCanonicalDoor(map) then
    return nil
  end

  return {
    kind = "building",
    semantic = "LAB",
    family = "PALLET_LAB",
    id = "PALLET_OAK_LAB",
    mapId = "PALLET_TOWN",
    -- The vanilla lab drawing occupies four gameplay rows, but its lower two
    -- rows are a front-facing facade. They encode height, not extra ground
    -- depth. Keep the complete source rectangle masked while giving the 3D
    -- building the two-cell roof depth implied by the top-facing roof band.
    groundClaim = { x0 = 10, y0 = 8, x1 = 16, y1 = 12 },
    footprint = { x0 = 10, y0 = 10, x1 = 16, y1 = 12 },
    door = { x = 12, y = 11, width = 1 },
    architecture = {
      wallHeight = 1.36,
      roofStyle = "hip",
      roofPeak = 2.34,
      roofThickness = 0.14,
      roofOverhang = 0.18,
      ridgeY = 11.0,
      ridgeInsetX = 1.0,
      doorHeight = 0.92,
      shadowInset = 0.04,
      -- The lab roof band is 32px deep and contains its own lower eave.
      roofUV = { 0, 0, 1, 0, 1, 0.875, 0, 0.875 },
      fasciaUV = { 0, 0.875, 1, 0.875, 1, 1, 0, 1 },
      roofSideUV = { 0, 0, 1, 0, 1, 1, 0, 1 },
    },
    materials = {
      roof = { x0 = 11, y0 = 8, x1 = 14, y1 = 9 },
      roofLeft = { x0 = 10, y0 = 8, x1 = 10, y1 = 9 },
      roofRight = { x0 = 15, y0 = 8, x1 = 15, y1 = 9 },
      facade = { x0 = 10, y0 = 10, x1 = 15, y1 = 11 },
      side = { x0 = 15, y0 = 10, x1 = 15, y1 = 11 },
      door = { x = 12, y = 11 },
    },
  }
end

return PalletOakLab
