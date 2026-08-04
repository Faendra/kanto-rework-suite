local Layout = {}

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

function Layout.classify(width, height)
  width = math.max(1, tonumber(width) or 1)
  height = math.max(1, tonumber(height) or 1)
  local ratio = width / height
  if ratio >= 1.35 then return "landscape" end
  if ratio <= 0.82 then return "portrait" end
  return "classic"
end

function Layout.safeArea(viewport)
  local width = math.max(1, viewport and viewport.width or 1)
  local height = math.max(1, viewport and viewport.height or 1)
  local margin = clamp(math.floor(math.min(width, height) * 0.025), 16, 40)
  return {
    x = margin,
    y = margin,
    w = math.max(1, width - margin * 2),
    h = math.max(1, height - margin * 2),
    margin = margin,
  }
end

function Layout.startMenu(viewport, rowCount)
  local safe = Layout.safeArea(viewport)
  local class = Layout.classify(viewport.width, viewport.height)
  local rowHeight
  local width
  local headerHeight
  local footerHeight

  if class == "landscape" then
    rowHeight = clamp(math.floor(viewport.height * 0.058), 50, 72)
    width = clamp(math.floor(viewport.width * 0.27), 380, 520)
    headerHeight = 68
    footerHeight = 58
  elseif class == "portrait" then
    rowHeight = clamp(math.floor(viewport.height * 0.041), 58, 76)
    width = math.min(safe.w, 560)
    headerHeight = 76
    footerHeight = 66
  else
    rowHeight = clamp(math.floor(viewport.height * 0.046), 54, 70)
    width = math.min(safe.w, 680)
    headerHeight = 72
    footerHeight = 62
  end

  local maxRows = math.max(1, math.floor((safe.h - headerHeight - footerHeight) / rowHeight))
  local visibleRows = math.min(math.max(1, rowCount or 1), maxRows)
  local height = headerHeight + visibleRows * rowHeight + footerHeight
  local x
  local y

  if class == "landscape" then
    x = safe.x + safe.w - width
    y = safe.y + math.max(0, (safe.h - height) * 0.5)
  else
    x = safe.x + math.max(0, (safe.w - width) * 0.5)
    y = safe.y + math.max(0, (safe.h - height) * 0.5)
  end

  return {
    class = class,
    x = math.floor(x + 0.5),
    y = math.floor(y + 0.5),
    w = math.floor(width + 0.5),
    h = math.floor(height + 0.5),
    rowHeight = rowHeight,
    headerHeight = headerHeight,
    footerHeight = footerHeight,
    visibleRows = visibleRows,
    safe = safe,
  }
end

function Layout.normalizedToWindow(profile, viewport, widgetWidth, widgetHeight)
  local safe = Layout.safeArea(viewport)
  local nx = clamp(tonumber(profile.widgetX) or 0.04, 0, 1)
  local ny = clamp(tonumber(profile.widgetY) or 0.08, 0, 1)
  local x = safe.x + nx * math.max(0, safe.w - widgetWidth)
  local y = safe.y + ny * math.max(0, safe.h - widgetHeight)
  return math.floor(x + 0.5), math.floor(y + 0.5)
end

function Layout.windowToNormalized(x, y, viewport, widgetWidth, widgetHeight)
  local safe = Layout.safeArea(viewport)
  local maxX = math.max(1, safe.w - widgetWidth)
  local maxY = math.max(1, safe.h - widgetHeight)
  return clamp((x - safe.x) / maxX, 0, 1), clamp((y - safe.y) / maxY, 0, 1)
end

return Layout
