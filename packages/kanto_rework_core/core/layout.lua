local Layout = {}

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

function Layout.classify(width, height)
  width = math.max(1, tonumber(width) or 1)
  height = math.max(1, tonumber(height) or 1)
  local ratio = width / height
  if ratio >= 1.45 then return "landscape" end
  if ratio <= 0.82 then return "portrait" end
  return "classic"
end

function Layout.safeArea(viewport)
  local width = math.max(1, tonumber(viewport and viewport.width) or 1)
  local height = math.max(1, tonumber(viewport and viewport.height) or 1)
  local margin = clamp(math.floor(math.min(width, height) * 0.028), 16, 42)
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
  local gap = clamp(math.floor(math.min(viewport.width, viewport.height) * 0.018), 12, 24)
  local rowHeight
  local menuW
  local infoW
  local headerHeight
  local footerHeight

  if class == "landscape" then
    rowHeight = clamp(math.floor(viewport.height * 0.064), 54, 74)
    menuW = clamp(math.floor(viewport.width * 0.30), 390, 520)
    infoW = clamp(math.floor(viewport.width * 0.22), 285, 390)
    headerHeight = 94
    footerHeight = 58
  elseif class == "portrait" then
    rowHeight = clamp(math.floor(viewport.height * 0.045), 58, 78)
    menuW = math.min(safe.w, 620)
    infoW = menuW
    headerHeight = 90
    footerHeight = 64
  else
    rowHeight = clamp(math.floor(viewport.height * 0.050), 54, 72)
    menuW = math.min(safe.w, 700)
    infoW = math.min(menuW, 520)
    headerHeight = 90
    footerHeight = 60
  end

  local maxRows
  if class == "portrait" then
    maxRows = math.max(1, math.floor((safe.h * 0.64 - headerHeight - footerHeight) / rowHeight))
  else
    maxRows = math.max(1, math.floor((safe.h - headerHeight - footerHeight) / rowHeight))
  end
  local visibleRows = math.min(math.max(1, rowCount or 1), maxRows)
  local menuH = headerHeight + visibleRows * rowHeight + footerHeight

  local menuX, menuY, infoX, infoY, infoH
  if class == "landscape" then
    menuX = safe.x + safe.w - menuW
    menuY = safe.y + math.max(0, (safe.h - menuH) * 0.5)
    infoX = safe.x
    infoH = clamp(math.floor(menuH * 0.60), 245, 390)
    infoY = safe.y + math.max(0, (safe.h - infoH) * 0.5)
  elseif class == "portrait" then
    infoH = clamp(math.floor(safe.h * 0.21), 190, 290)
    infoX = safe.x + math.max(0, (safe.w - infoW) * 0.5)
    infoY = safe.y
    menuX = safe.x + math.max(0, (safe.w - menuW) * 0.5)
    menuY = math.min(safe.y + safe.h - menuH, infoY + infoH + gap)
  else
    menuX = safe.x + math.max(0, (safe.w - menuW) * 0.5)
    menuY = safe.y + math.max(0, (safe.h - menuH) * 0.5)
    infoH = 0
    infoX = safe.x
    infoY = safe.y
  end

  return {
    class = class,
    x = math.floor(menuX + 0.5),
    y = math.floor(menuY + 0.5),
    w = math.floor(menuW + 0.5),
    h = math.floor(menuH + 0.5),
    rowHeight = rowHeight,
    headerHeight = headerHeight,
    footerHeight = footerHeight,
    visibleRows = visibleRows,
    safe = safe,
    gap = gap,
    info = {
      x = math.floor(infoX + 0.5),
      y = math.floor(infoY + 0.5),
      w = math.floor(infoW + 0.5),
      h = math.floor(infoH + 0.5),
      visible = infoH > 0,
    },
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
