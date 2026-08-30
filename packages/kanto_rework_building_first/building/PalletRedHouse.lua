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

local function skinRegion(name)
  return { x0 = "FIRERED:" .. name, y0 = 0, x1 = 0, y1 = 0 }
end

function PalletRedHouse.detect(map)
  if not map or map.id ~= "PALLET_TOWN" or not hasCanonicalDoor(map) then
    return nil
  end

  -- ARCHITECTURE-VOLUME-01
  -- groundClaim is the complete vanilla projection removed from the flat map.
  -- architecture.footprint is independently authored, but for this house the
  -- observed projection depth is also occupied by the reconstructed building.
  local volume = { x0 = 4, y0 = 2, x1 = 8, y1 = 6 }
  local occlusion = { x0 = 3.82, y0 = 1.82, x1 = 8.18, y1 = 6.18 }

  return {
    kind = "building",
    semantic = "HOUSE",
    family = "PALLET_HOUSE",
    id = "PALLET_RED_HOUSE",
    mapId = "PALLET_TOWN",
    visualSkin = "FIRERED_PALLET_HOUSE_V1",
    groundClaim = { x0 = 4, y0 = 2, x1 = 8, y1 = 6 },

    -- Compatibility alias consumed by the generic renderer. It is the authored
    -- architectural footprint, never inferred from source pixels.
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
      ridgeY = 4.0,
      ridgeInsetX = 1.0,
      doorHeight = 0.92,
      shadowInset = 0.04,

      -- FireRed material density: the 32px roof field represents two 16px
      -- cells. Repeat it twice over the four-cell house width instead of
      -- stretching one sample over the complete roof plane. The bottom quarter
      -- of the compact material is an authored fascia strip.
      roofUV = { 0, 0, 2, 0, 2, 0.75, 0, 0.75 },
      fasciaUV = { 0, 0.75, 2, 0.75, 2, 1, 0, 1 },
      roofSideUV = { 0, 0, 1, 0, 1, 1, 0, 1 },
    },

    -- Visual occlusion can include the authored roof overhang. This metadata
    -- does not alter Gen1Recomp collision, warp or actor coordinates.
    occlusion = {
      footprint = occlusion,
      frontY = 6.18,
      rearY = 1.82,
    },

    -- VISUAL-SKIN-FIRERED-01. These are semantic material slots, not map-cell
    -- coordinates. AtlasSource resolves the FIRERED namespace to the compact
    -- palette/texture fragments taken from the supplied FRLG Pallet house.
    materials = {
      roof = skinRegion("roof"),
      roofLeft = skinRegion("roofLeft"),
      roofRight = skinRegion("roofRight"),
      facade = skinRegion("facade"),
      side = skinRegion("side"),
      door = { x = "FIRERED:door", y = 0 },
    },
  }
end

return PalletRedHouse
