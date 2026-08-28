local SceneProfiles = {}

local function key(x, y)
  return y * 4096 + x
end

-- Audited against pret/pokered maps/PalletTown.blk.  These ids are used only
-- after the Pallet dimensions + tileset signature matches; they never become
-- global OVERWORLD assumptions.
local PALLET_BUILDING_BLOCKS = {
  [0x38] = true, [0x39] = true, [0x3c] = true, [0x3d] = true,
  [0x0c] = true, [0x0d] = true, [0x0e] = true,
  [0x10] = true, [0x3a] = true, [0x00] = true,
}

local function palletSignature(snapshot)
  local def = snapshot.mapDef
  return snapshot.mapId == "PALLET_TOWN"
    and def ~= nil
    and def.tileset == "OVERWORLD"
    and def.width == 10
    and def.height == 9
    and type(def.blocks) == "table"
    and #def.blocks >= 90
end

local function blockAt(def, bx, by)
  if bx < 0 or by < 0 or bx >= def.width or by >= def.height then return nil end
  return def.blocks[by * def.width + bx + 1]
end

local function buildingComponents(def)
  local out, seen = {}, {}
  local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

  for by = 0, def.height - 1 do
    for bx = 0, def.width - 1 do
      local startKey = key(bx, by)
      if not seen[startKey] and PALLET_BUILDING_BLOCKS[blockAt(def, bx, by)] then
        local queue = { { bx, by } }
        local qi = 1
        seen[startKey] = true
        local cells = {}
        local minX, maxX, minY, maxY = bx, bx, by, by

        while queue[qi] do
          local cur = queue[qi]
          qi = qi + 1
          local cx, cy = cur[1], cur[2]
          cells[#cells + 1] = cur
          if cx < minX then minX = cx end
          if cx > maxX then maxX = cx end
          if cy < minY then minY = cy end
          if cy > maxY then maxY = cy end

          for _, d in ipairs(dirs) do
            local nx, ny = cx + d[1], cy + d[2]
            local nk = key(nx, ny)
            if nx >= 0 and ny >= 0 and nx < def.width and ny < def.height
                and not seen[nk]
                and PALLET_BUILDING_BLOCKS[blockAt(def, nx, ny)] then
              seen[nk] = true
              queue[#queue + 1] = { nx, ny }
            end
          end
        end

        -- The canonical Pallet components are 2x2, 2x2 and 3x2 blocks.
        -- Reject tiny accidental matches if another mod changes the layout.
        if #cells >= 4 then
          local wBlocks, hBlocks = maxX - minX + 1, maxY - minY + 1
          out[#out + 1] = {
            x = minX * 2,
            y = minY * 2,
            w = wBlocks * 2,
            h = hBlocks * 2,
            kind = wBlocks >= 3 and "lab" or "house",
            blockCount = #cells,
            doors = {},
          }
        end
      end
    end
  end
  return out
end

local function attachDoors(def, structures)
  for _, warp in ipairs(def.warps or {}) do
    for _, s in ipairs(structures) do
      if warp.x >= s.x and warp.x < s.x + s.w
          and warp.y >= s.y and warp.y < s.y + s.h then
        s.doors[#s.doors + 1] = { x = warp.x, y = warp.y }
        break
      end
    end
  end
end

local function markStructures(structures)
  local mask = {}
  for index, s in ipairs(structures) do
    for y = s.y, s.y + s.h - 1 do
      for x = s.x, s.x + s.w - 1 do
        mask[key(x, y)] = index
      end
    end
  end
  return mask
end

local function markPalletVegetation(snapshot, structureCells)
  local out = {}
  local overview = snapshot.overview
  if not overview then return out end

  -- The authored pass only promotes the dense outer ring to volumetric
  -- vegetation.  Interior blocked cells remain low obstacles until a later
  -- tileset semantic table can distinguish signs/fences/flower beds safely.
  for y = 0, overview.height - 1 do
    local row = overview.rows and overview.rows[y + 1]
    for x = 0, overview.width - 1 do
      local ch = row and row:sub(x + 1, x + 1) or nil
      local edge = x <= 1 or y <= 1
        or x >= overview.width - 2 or y >= overview.height - 2
      if edge and ch == " " and not structureCells[key(x, y)] then
        out[key(x, y)] = true
      end
    end
  end
  return out
end

function SceneProfiles.build(snapshot)
  if not palletSignature(snapshot) then
    return {
      name = "semantic",
      authored = false,
      structures = {},
      structureCells = {},
      vegetationCells = {},
    }
  end

  local structures = buildingComponents(snapshot.mapDef)
  attachDoors(snapshot.mapDef, structures)
  local structureCells = markStructures(structures)

  return {
    name = "pallet_town_v1",
    authored = true,
    structures = structures,
    structureCells = structureCells,
    vegetationCells = markPalletVegetation(snapshot, structureCells),
  }
end

function SceneProfiles.cellKey(x, y)
  return key(x, y)
end

return SceneProfiles
