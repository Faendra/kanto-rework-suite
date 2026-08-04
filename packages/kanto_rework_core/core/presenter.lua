return function(deps)
  local Layout = assert(deps.Layout)
  local Theme = assert(deps.Theme)
  local runtime = assert(deps.runtime)

  local fonts = {}

  local function font(size)
    size = math.max(10, math.floor(size + 0.5))
    if not fonts[size] then fonts[size] = love.graphics.newFont(size) end
    return fonts[size]
  end

  local function text(value)
    if value == nil then return "" end
    return tostring(value)
  end

  local function topState(game)
    if not (game and game.stack and game.stack.top) then return nil end
    local ok, state = pcall(game.stack.top, game.stack)
    if not ok then return nil end
    return state
  end

  local function isSupportedStartMenu(game)
    local state = topState(game)
    if type(state) ~= "table" or state.screenId ~= "StartMenu" then return false end
    if type(state.items) ~= "table" or type(state.index) ~= "number" then return false end
    if not state.startCloses then return false end
    if game.save and game.save.safari then return false end
    return true, state
  end

  local function roundedShadow(x, y, w, h, radius, color)
    Theme.setColor(color)
    love.graphics.rectangle("fill", x + 8, y + 10, w, h, radius)
  end

  local function actionHint(inputSource)
    if inputSource == "mouse" then return "Left click  Select    Right click  Back    Wheel  Navigate" end
    if inputSource == "touch" then return "Tap  Select    Swipe or controls  Navigate" end
    if inputSource == "controller" then return "A  Select    B  Back" end
    return "Enter  Select    Esc  Back    F8  Overlay    F9  Edit overlay"
  end

  local function drawStartMenu(game, viewport, profile)
    local supported, state = isSupportedStartMenu(game)
    if not supported then return false end

    local theme = Theme.get(profile.theme)
    local rows = state.items
    local layout = Layout.startMenu(viewport, #rows)
    local selected = math.max(1, math.min(#rows, state.index or 1))
    local scroll = math.max(0, tonumber(state.scroll) or 0)
    local maxScroll = math.max(0, #rows - layout.visibleRows)
    scroll = math.max(0, math.min(maxScroll, scroll))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + layout.visibleRows then
      scroll = selected - layout.visibleRows
    end

    runtime.startMenu = {
      state = state,
      layout = layout,
      scroll = scroll,
      regions = {},
    }

    love.graphics.push("all")
    love.graphics.origin()
    roundedShadow(layout.x, layout.y, layout.w, layout.h, 18, theme.shadow)
    Theme.setColor(theme.paper)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h, 18)
    Theme.setColor(theme.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", layout.x, layout.y, layout.w, layout.h, 18)

    Theme.setColor(theme.accent)
    love.graphics.rectangle("fill", layout.x, layout.y, 8, layout.h)

    love.graphics.setFont(font(13))
    Theme.setColor(theme.accent)
    love.graphics.print("FIELD MENU", layout.x + 28, layout.y + 18)
    love.graphics.setFont(font(30))
    Theme.setColor(theme.ink)
    love.graphics.print("KANTO", layout.x + 28, layout.y + 34)

    local contentY = layout.y + layout.headerHeight
    for visibleIndex = 1, layout.visibleRows do
      local itemIndex = scroll + visibleIndex
      local item = rows[itemIndex]
      if not item then break end
      local rowY = contentY + (visibleIndex - 1) * layout.rowHeight
      local hovered = runtime.hoveredItem == itemIndex
      local active = itemIndex == selected
      if active or hovered then
        Theme.setColor(active and theme.accentSoft or {
          theme.accent[1], theme.accent[2], theme.accent[3], 0.09,
        })
        love.graphics.rectangle("fill", layout.x + 18, rowY + 5,
          layout.w - 36, layout.rowHeight - 10, 12)
      end
      if active then
        Theme.setColor(theme.accent)
        love.graphics.rectangle("fill", layout.x + 18, rowY + 14, 5,
          layout.rowHeight - 28, 3)
      end
      love.graphics.setFont(font(math.max(18, math.floor(layout.rowHeight * 0.36))))
      Theme.setColor(active and theme.ink or theme.muted)
      love.graphics.print(text(item.label), layout.x + 36,
        rowY + (layout.rowHeight - love.graphics.getFont():getHeight()) * 0.5)
      runtime.startMenu.regions[#runtime.startMenu.regions + 1] = {
        kind = "menu_row",
        itemIndex = itemIndex,
        x = layout.x + 14,
        y = rowY,
        w = layout.w - 28,
        h = layout.rowHeight,
      }
    end

    local footerY = layout.y + layout.h - layout.footerHeight
    Theme.setColor(theme.border, 0.48)
    love.graphics.rectangle("fill", layout.x + 24, footerY,
      layout.w - 48, 1)
    love.graphics.setFont(font(13))
    Theme.setColor(theme.muted)
    love.graphics.print(actionHint(runtime.lastInput), layout.x + 28,
      footerY + (layout.footerHeight - love.graphics.getFont():getHeight()) * 0.5)

    if scroll > 0 then
      Theme.setColor(theme.accent)
      love.graphics.polygon("fill", layout.x + layout.w - 28, contentY + 12,
        layout.x + layout.w - 20, contentY + 24,
        layout.x + layout.w - 36, contentY + 24)
    end
    if scroll < maxScroll then
      local bottomY = footerY - 12
      Theme.setColor(theme.accent)
      love.graphics.polygon("fill", layout.x + layout.w - 28, bottomY,
        layout.x + layout.w - 20, bottomY - 12,
        layout.x + layout.w - 36, bottomY - 12)
    end

    love.graphics.pop()
    return true
  end

  local function drawOverlay(viewport, profile)
    runtime.overlayRegion = nil
    if not profile.overlayVisible then return end

    local theme = Theme.get(profile.theme)
    local class = Layout.classify(viewport.width, viewport.height)
    local scale = math.max(0.82, math.min(1.18,
      math.min(viewport.width / 1920, viewport.height / 1080) + 0.22))
    local width = math.floor((class == "portrait" and 300 or 340) * scale)
    local height = math.floor(154 * scale)
    local x, y = Layout.normalizedToWindow(profile, viewport, width, height)

    runtime.overlayRegion = {
      kind = "overlay",
      x = x,
      y = y,
      w = width,
      h = height,
      headerH = math.floor(38 * scale),
    }

    love.graphics.push("all")
    love.graphics.origin()
    roundedShadow(x, y, width, height, 16, theme.shadow)
    Theme.setColor(theme.paperRaised)
    love.graphics.rectangle("fill", x, y, width, height, 16)
    Theme.setColor(runtime.editMode and theme.accent or theme.border)
    love.graphics.setLineWidth(runtime.editMode and 3 or 2)
    love.graphics.rectangle("line", x, y, width, height, 16)

    Theme.setColor(theme.accent)
    love.graphics.rectangle("fill", x, y, width, runtime.overlayRegion.headerH)
    love.graphics.setFont(font(math.max(13, math.floor(14 * scale))))
    Theme.setColor(theme.paperRaised)
    love.graphics.print(runtime.editMode and "OVERLAY EDIT MODE" or "KANTO COMPANION",
      x + 16, y + 10 * scale)

    love.graphics.setFont(font(math.max(15, math.floor(17 * scale))))
    Theme.setColor(theme.ink)
    love.graphics.print("Technical spike active", x + 18,
      y + runtime.overlayRegion.headerH + 18 * scale)
    love.graphics.setFont(font(math.max(12, math.floor(13 * scale))))
    Theme.setColor(theme.muted)
    love.graphics.print("Layout: " .. class, x + 18,
      y + runtime.overlayRegion.headerH + 50 * scale)
    love.graphics.print("Input: " .. (runtime.lastInput or "keyboard"), x + 18,
      y + runtime.overlayRegion.headerH + 73 * scale)
    love.graphics.print(profile.widgetLocked and "Locked" or "F9: drag to reposition",
      x + 18, y + runtime.overlayRegion.headerH + 96 * scale)
    love.graphics.pop()
  end

  local function hitTest(x, y)
    local menu = runtime.startMenu
    if menu then
      for _, region in ipairs(menu.regions or {}) do
        if x >= region.x and x <= region.x + region.w
            and y >= region.y and y <= region.y + region.h then
          return region
        end
      end
    end
    local overlay = runtime.overlayRegion
    if overlay and x >= overlay.x and x <= overlay.x + overlay.w
        and y >= overlay.y and y <= overlay.y + overlay.h then
      return overlay
    end
    return nil
  end

  return {
    topState = topState,
    isSupportedStartMenu = isSupportedStartMenu,
    drawStartMenu = drawStartMenu,
    drawOverlay = drawOverlay,
    hitTest = hitTest,
  }
end
