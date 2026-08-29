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

  -- Pokemon Red source ground truth:
  -- PalletTown.blk places Oak's lab in a 3x2 block motif at blocks x=5..7,
  -- y=4..5, which maps to gameplay cells x=10..15, y=8..11. The canonical
  -- OAKS_LAB warp is at cell (12,11). The source roof has a central field
  -- flanked by two hip faces, so the semantic architecture uses a hip roof.
  return {
    kind = "building",
    semantic = "LAB",
    family = "PALLET_LAB",
    id = "PALLET_OAK_LAB",
    mapId = "PALLET_TOWN",
    footprint = { x0 = 10, y0 = 8, x1 = 16, y1 = 12 },
    door = { x = 12, y = 11, width = 1 },
    architecture = {
      wallHeight = 1.36,
      roofStyle = "hip",
      roofPeak = 2.34,
      roofThickness = 0.14,
      roofOverhang = 0.18,
      ridgeY = 10.0,
      ridgeInsetX = 1.0,
      doorHeight = 0.92,
      shadowInset = 0.04,
      -- The central lab-roof material contains both the patterned plane and
      -- its lower eave band. Keep the plane above that band; fascia consumes
      -- the bottom strip separately.
      roofUV = { 0, 0, 1, 0, 1, 0.78, 0, 0.78 },
      fasciaUV = { 0, 0.75, 1, 0.75, 1, 1, 0, 1 },
      roofSideUV = { 0, 0, 1, 0, 1, 1, 0, 1 },
    },
    materials = {
      -- Roof cells are semantically split instead of baking the 2D side hips
      -- into the central roof plane.
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
