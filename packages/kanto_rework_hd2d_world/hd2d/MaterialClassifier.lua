local MaterialClassifier = {}

local function safeCall(object, method, ...)
  if not object or type(object[method]) ~= "function" then return nil end
  local ok, value = pcall(object[method], object, ...)
  if ok then return value end
  return nil
end

function MaterialClassifier.classify(map, cx, cy)
  if not map then return { kind = "void", height = 0 } end
  if safeCall(map, "inBounds", cx, cy) == false then
    return { kind = "void", height = 0 }
  end

  if safeCall(map, "isWaterCell", cx, cy) then
    return { kind = "water", height = -1 }
  end
  if safeCall(map, "isGrassCell", cx, cy) then
    return { kind = "grass", height = 0 }
  end
  if safeCall(map, "isWalkableCell", cx, cy) then
    return { kind = "ground", height = 0 }
  end

  -- Non-walkable background art becomes one shallow raised terrain mass.
  -- This is facade relief, not voxelization.
  return { kind = "solid", height = 1 }
end

function MaterialClassifier.reliefHeight(material, baseLift)
  if not material then return 0 end
  if material.kind == "solid" then return baseLift or 6 end
  if material.kind == "water" then return -1 end
  return 0
end

function MaterialClassifier.frontExposed(map, cx, cy)
  local here = MaterialClassifier.classify(map, cx, cy)
  if here.kind ~= "solid" then return false end
  local front = MaterialClassifier.classify(map, cx, cy + 1)
  return front.kind ~= "solid"
end

function MaterialClassifier.sideExposed(map, cx, cy, dx)
  local here = MaterialClassifier.classify(map, cx, cy)
  if here.kind ~= "solid" then return false end
  local side = MaterialClassifier.classify(map, cx + dx, cy)
  return side.kind ~= "solid"
end

return MaterialClassifier
