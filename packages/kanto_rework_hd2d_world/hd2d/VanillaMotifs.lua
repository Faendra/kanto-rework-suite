local VanillaMotifs = {}

local OVERWORLD = "OVERWORLD"

-- Canonical 2x2 visual motifs from pokered's Overworld tileset/blockset.
-- These are tile identities, not map coordinates: any OVERWORLD cell using the
-- same vanilla motif receives the same presentation semantics.
local TREE = { 0x2A, 0x2B, 0x3A, 0x3B }
local BOULDER = { 0x40, 0x41, 0x50, 0x51 }
local LAWN_TILE = 0x2C
local PATH_TILE = 0x39

local function safeTileAt(map, tx, ty)
  if not map or type(map.tileAt) ~= "function" then return nil end
  local ok, value = pcall(map.tileAt, map, tx, ty)
  return ok and value or nil
end

local function same4(q, motif)
  return q and q[1] == motif[1] and q[2] == motif[2]
      and q[3] == motif[3] and q[4] == motif[4]
end

local function count(q, value)
  local n = 0
  for i = 1, 4 do if q and q[i] == value then n = n + 1 end end
  return n
end

function VanillaMotifs.quartet(map, cx, cy)
  if not (map and map.def and map.def.tileset == OVERWORLD) then return nil end
  local tx, ty = cx * 2, cy * 2
  local a = safeTileAt(map, tx, ty)
  local b = safeTileAt(map, tx + 1, ty)
  local c = safeTileAt(map, tx, ty + 1)
  local d = safeTileAt(map, tx + 1, ty + 1)
  if a == nil or b == nil or c == nil or d == nil then return nil end
  return { a, b, c, d }
end

function VanillaMotifs.cellMotif(map, cx, cy)
  local q = VanillaMotifs.quartet(map, cx, cy)
  if not q then return nil end
  if same4(q, TREE) then return "tree" end
  if same4(q, BOULDER) then return "boulder" end

  local lawn = count(q, LAWN_TILE)
  local path = count(q, PATH_TILE)
  if lawn >= 3 then return "lawn" end
  if path >= 3 then return "path" end
  return nil
end

function VanillaMotifs.surfaceKind(map, cx, cy, material)
  if material and material.kind == "water" then return "water" end
  if material and material.kind == "grass" then return "lawn" end
  local motif = VanillaMotifs.cellMotif(map, cx, cy)
  if motif == "tree" or motif == "boulder" then return "lawn" end
  if motif == "lawn" or motif == "path" then return motif end
  return "neutral"
end

function VanillaMotifs.install(classifier)
  if not classifier or classifier.__vanillaMotifsInstalled then return classifier end
  classifier.__vanillaMotifsInstalled = true
  local baseClassify = classifier.classify

  classifier.classify = function(map, cx, cy)
    local material = baseClassify(map, cx, cy)
    if not (map and map.def and map.def.tileset == OVERWORLD) then
      return material
    end

    local motif = VanillaMotifs.cellMotif(map, cx, cy)
    material.motif = motif
    material.surface = VanillaMotifs.surfaceKind(map, cx, cy, material)

    if material.kind == "solid" and motif == "tree" then
      material.family = "vegetation"
      material.heightScale = math.max(1.90, material.heightScale or 0)
    elseif material.kind == "solid" and motif == "boulder" then
      material.family = "boundary"
      material.heightScale = math.max(0.95, material.heightScale or 0)
    end
    return material
  end
  return classifier
end

VanillaMotifs.TREE = TREE
VanillaMotifs.BOULDER = BOULDER
VanillaMotifs.LAWN_TILE = LAWN_TILE
VanillaMotifs.PATH_TILE = PATH_TILE

return VanillaMotifs
