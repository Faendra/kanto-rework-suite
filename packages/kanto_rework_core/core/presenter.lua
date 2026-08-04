return function(deps)
  local Layout = assert(deps.Layout)
  local Theme = assert(deps.Theme)
  local runtime = assert(deps.runtime)
  local menuClass = deps.MenuClass

  local fonts = {}

  local function font(size)
    size = math.max(10, math.floor((tonumber(size) or 12) + 0.5))
    if not fonts[size] then fonts[size] = love.graphics.newFont(size) end
    return fonts[size]
  end

  local function text(value)
    if value == nil then return "" end
    return tostring(value)
  end

  local function classOf(state)
    local mt = state and getmetatable(state)
    return mt and mt.__index
  end

  local function inherits(class, target, seen)
    if not target then return false end
    if class == target then return true end
    if type(class) ~= "table" then return false end
    seen = seen or {}
    if seen[class] then return false end
    seen[class] = true
    local mt = getmetatable(class)
    return mt and inherits(mt.__index, target, seen) or false
  end

  local function topState(game)
    if not (game and game.stack) then return nil end
    if type(game.stack.top) == "function" then
      local ok, state = pcall(game.stack.top, game.stack)
      if ok then return state end
    end
    local states = game.stack.states
    return type(states) == "table" and states[#states] or nil
  end

  -- The released StartMenu factory returns a generic Menu instance. Depending
  -- on how it was pushed, screenId may be absent. `startCloses` plus the live
  -- items/index contract is the stable semantic identity used by the engine.
  local function isSupportedStartMenu(game)
    local state = topState(game)
    if type(state) ~= "table" or type(state.items) ~= "table"
        or type(state.index) ~= "number" or state.startCloses ~= true then
      return false, state, "top state is not a Start-menu contract"
    end
    if type(state.titleUiBox) == "table" then
      return false, state, "title menu is intentionally excluded"
    end
    if state.screenId == "StartMenu" then return true, state, "screenId" end
    if menuClass and inherits(classOf(state), menuClass) then
      return true, state, "Menu class + startCloses"
    end
    -- Structural fallback for compatible mods that clone the released Menu
    -- contract without retaining its metatable.
    return true, state, "structural startCloses contract"
  end

  local function roundedShadow(x, y, w, h, radius, color, offset)
    Theme.setColor(color)
    offset = offset or 10
    love.graphics.rectangle("fill", x + offset, y + offset, w, h, radius)
  end

  local function line(theme, x, y, w)
    Theme.setColor(theme.divider)
    love.graphics.rectangle("fill", x, y, w, 1)
  end

  local function actionHint(inputSource)
    if inputSource == "mouse" then
      return "LEFT CLICK  SELECT     RIGHT CLICK  BACK     WHEEL  NAVIGATE"
    end
    if inputSource == "touch" then return "TAP  SELECT     SWIPE / CONTROLS  NAVIGATE" end
    if inputSource == "controller" then return "A  SELECT     B  BACK" end
    return "ENTER  SELECT     ESC  BACK     F8  OVERLAY     F9  EDIT"
  end

  local function countKeys(value)
    local count = 0
    for _ in pairs(type(value) == "table" and value or {}) do count = count + 1 end
    return count
  end

  local function trainerSummary(game)
    local save = game and game.save or {}
    local player = save.player or {}
    local mapName = "KANTO"
    local overworld = game and game.overworld
    local map = overworld and overworld.map
    if type(map) == "table" then
      mapName = map.name or (map.def and map.def.name) or map.id or mapName
    elseif player.map then
      local def = game and game.data and game.data.maps and game.data.maps[player.map]
      mapName = def and def.name or player.map
    end
    local seconds = math.max(0, math.floor(tonumber(save.playTime) or 0))
    return {
      name = text(player.name ~= nil and player.name or "RED"),
      map = text(mapName):gsub("_", " "),
      money = math.floor(tonumber(save.money or player.money) or 0),
      party = #(type(save.party) == "table" and save.party or {}),
      owned = countKeys(save.pokedex and save.pokedex.owned),
      seen = countKeys(save.pokedex and save.pokedex.seen),
      time = ("%02d:%02d"):format(math.floor(seconds / 3600),
        math.floor(seconds / 60) % 60),
    }
  end

  local function drawInfoCard(game, layout, theme)
    local info = layout.info
    if not info.visible then return end
    local summary = trainerSummary(game)
    roundedShadow(info.x, info.y, info.w, info.h, 18, theme.shadow, 8)
    Theme.setColor(theme.night)
    love.graphics.rectangle("fill", info.x, info.y, info.w, info.h, 18)
    Theme.setColor(theme.accent)
    love.graphics.rectangle("fill", info.x, info.y, 7, info.h, 18, 0, 0, 18)

    local pad = 24
    love.graphics.setFont(font(13))
    Theme.setColor(theme.nightMuted)
    love.graphics.print("TRAINER FILE", info.x + pad, info.y + 20)
    love.graphics.setFont(font(30))
    Theme.setColor(theme.nightText)
    love.graphics.print(summary.name, info.x + pad, info.y + 40)
    love.graphics.setFont(font(14))
    Theme.setColor(theme.accent)
    love.graphics.print(summary.map:upper(), info.x + pad, info.y + 78)

    line({ divider = { 1, 1, 1, 0.13 } }, info.x + pad, info.y + 108,
      info.w - pad * 2)

    local bodyY = info.y + 126
    local column = (info.w - pad * 2) / 2
    local rows = {
      { "MONEY", ("¥%d"):format(summary.money), 0, 0 },
      { "PLAY TIME", summary.time, 1, 0 },
      { "PARTY", ("%d/6"):format(summary.party), 0, 1 },
      { "POKéDEX", ("%d / %d"):format(summary.owned, summary.seen), 1, 1 },
    }
    for _, row in ipairs(rows) do
      local x = info.x + pad + row[3] * column
      local y = bodyY + row[4] * 58
      love.graphics.setFont(font(11))
      Theme.setColor(theme.nightMuted)
      love.graphics.print(row[1], x, y)
      love.graphics.setFont(font(20))
      Theme.setColor(theme.nightText)
      love.graphics.print(row[2], x, y + 17)
    end
  end

  local function drawCompactSummary(game, layout, theme)
    local summary = trainerSummary(game)
    love.graphics.setFont(font(12))
    Theme.setColor(theme.muted)
    local value = ("%s   •   %s   •   PARTY %d/6   •   ¥%d"):format(
      summary.name, summary.map:upper(), summary.party, summary.money)
    love.graphics.print(value, layout.x + 28, layout.y + 66)
  end

  local function drawStartMenu(game, viewport, profile)
    local supported, state, reason = isSupportedStartMenu(game)
    runtime.supportReason = reason
    if not supported then return false end

    local theme = Theme.get(profile.theme)
    local rows = state.items
    local layout = Layout.startMenu(viewport, #rows)
    local selected = math.max(1, math.min(#rows, state.index or 1))
    local scroll = math.max(0, tonumber(state.scroll) or 0)
    local maxScroll = math.max(0, #rows - layout.visibleRows)
    scroll = math.max(0, math.min(maxScroll, scroll))
    if selected <= scroll then scroll = selected - 1 end
    if selected > scroll + layout.visibleRows then scroll = selected - layout.visibleRows end

    runtime.startMenu = {
      state = state,
      layout = layout,
      scroll = scroll,
      regions = {},
    }

    love.graphics.push("all")
    love.graphics.origin()

    Theme.setColor(theme.backdrop)
    love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)
    drawInfoCard(game, layout, theme)

    roundedShadow(layout.x, layout.y, layout.w, layout.h, 20, theme.shadow, 10)
    Theme.setColor(theme.paper)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h, 20)
    Theme.setColor(theme.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", layout.x + 1, layout.y + 1,
      layout.w - 2, layout.h - 2, 20)

    Theme.setColor(theme.accent)
    love.graphics.rectangle("fill", layout.x, layout.y, 8, layout.h, 20, 0, 0, 20)
    love.graphics.rectangle("fill", layout.x + 24, layout.y + 17, 54, 4, 2)

    love.graphics.setFont(font(12))
    Theme.setColor(theme.accentDark)
    love.graphics.print("FIELD JOURNAL", layout.x + 28, layout.y + 28)
    love.graphics.setFont(font(30))
    Theme.setColor(theme.ink)
    love.graphics.print("KANTO", layout.x + 28, layout.y + 44)
    love.graphics.setFont(font(12))
    Theme.setColor(theme.subtle)
    love.graphics.print(("%02d ENTRIES"):format(#rows),
      layout.x + layout.w - 104, layout.y + 53)

    if layout.class == "classic" then drawCompactSummary(game, layout, theme) end

    local contentY = layout.y + layout.headerHeight
    line(theme, layout.x + 24, contentY - 1, layout.w - 48)
    for visibleIndex = 1, layout.visibleRows do
      local itemIndex = scroll + visibleIndex
      local item = rows[itemIndex]
      if not item then break end
      local rowY = contentY + (visibleIndex - 1) * layout.rowHeight
      local hovered = runtime.hoveredItem == itemIndex
      local active = itemIndex == selected
      local rx = layout.x + 18
      local rw = layout.w - 36
      if active then
        Theme.setColor(theme.accent)
        love.graphics.rectangle("fill", rx, rowY + 5, rw,
          layout.rowHeight - 10, 11)
      elseif hovered then
        Theme.setColor(theme.accentSoft)
        love.graphics.rectangle("fill", rx, rowY + 5, rw,
          layout.rowHeight - 10, 11)
      end

      love.graphics.setFont(font(11))
      Theme.setColor(active and theme.onAccent or theme.subtle)
      love.graphics.print(("%02d"):format(itemIndex), rx + 14,
        rowY + (layout.rowHeight - 11) * 0.5)
      love.graphics.setFont(font(math.max(18, math.floor(layout.rowHeight * 0.34))))
      Theme.setColor(active and theme.onAccent or theme.ink)
      love.graphics.print(text(item.label), rx + 56,
        rowY + (layout.rowHeight - love.graphics.getFont():getHeight()) * 0.5)

      if active then
        Theme.setColor(theme.onAccent)
        local arrowX = rx + rw - 28
        local cy = rowY + layout.rowHeight * 0.5
        love.graphics.polygon("fill", arrowX, cy - 7,
          arrowX + 10, cy, arrowX, cy + 7)
      end

      runtime.startMenu.regions[#runtime.startMenu.regions + 1] = {
        kind = "menu_row",
        itemIndex = itemIndex,
        x = rx,
        y = rowY,
        w = rw,
        h = layout.rowHeight,
      }
    end

    local footerY = layout.y + layout.h - layout.footerHeight
    line(theme, layout.x + 24, footerY, layout.w - 48)
    love.graphics.setFont(font(11))
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

  local function drawOverlay(game, viewport, profile)
    runtime.overlayRegion = nil
    if not profile.overlayVisible then return false end
    if isSupportedStartMenu(game) then return false end

    local theme = Theme.get(profile.theme)
    local class = Layout.classify(viewport.width, viewport.height)
    local scale = math.max(0.82, math.min(1.18,
      math.min(viewport.width / 1920, viewport.height / 1080) + 0.22))
    local width = math.floor((class == "portrait" and 300 or 350) * scale)
    local height = math.floor(164 * scale)
    local x, y = Layout.normalizedToWindow(profile, viewport, width, height)
    local summary = trainerSummary(game)

    runtime.overlayRegion = {
      kind = "overlay", x = x, y = y, w = width, h = height,
      headerH = math.floor(38 * scale),
    }

    love.graphics.push("all")
    love.graphics.origin()
    roundedShadow(x, y, width, height, 16, theme.shadow, 7)
    Theme.setColor(theme.night)
    love.graphics.rectangle("fill", x, y, width, height, 16)
    Theme.setColor(runtime.editMode and theme.accent or theme.border)
    love.graphics.setLineWidth(runtime.editMode and 3 or 1.5)
    love.graphics.rectangle("line", x, y, width, height, 16)

    Theme.setColor(theme.accent)
    love.graphics.rectangle("fill", x, y, width, runtime.overlayRegion.headerH,
      16, 16, 0, 0)
    love.graphics.setFont(font(math.max(12, math.floor(13 * scale))))
    Theme.setColor(theme.onAccent)
    love.graphics.print(runtime.editMode and "OVERLAY EDIT MODE" or "KANTO COMPANION",
      x + 15, y + 10 * scale)

    love.graphics.setFont(font(math.max(17, math.floor(20 * scale))))
    Theme.setColor(theme.nightText)
    love.graphics.print(summary.name, x + 17,
      y + runtime.overlayRegion.headerH + 15 * scale)
    love.graphics.setFont(font(math.max(11, math.floor(12 * scale))))
    Theme.setColor(theme.accent)
    love.graphics.print(summary.map:upper(), x + 17,
      y + runtime.overlayRegion.headerH + 43 * scale)
    Theme.setColor(theme.nightMuted)
    love.graphics.print(("PARTY %d/6     ¥%d     %s"):format(
      summary.party, summary.money, summary.time), x + 17,
      y + runtime.overlayRegion.headerH + 70 * scale)
    love.graphics.print(runtime.editMode and "DRAG THE RED HEADER • F9 TO LOCK"
      or "F8 HIDE • F9 EDIT", x + 17,
      y + runtime.overlayRegion.headerH + 99 * scale)
    love.graphics.pop()
    return true
  end

  local function drawDiagnostics(game, viewport, profile, enabled)
    if not enabled then return end
    local theme = Theme.get(profile.theme)
    local ok, state, reason = isSupportedStartMenu(game)
    local label = ("KRS 0.0.4  •  HUD ACTIVE  •  %s  •  %s"):format(
      ok and "START MENU DETECTED" or "NATIVE WORLD",
      text(reason or (state and state.screenId) or "unknown"))
    local f = font(11)
    local width = math.min(viewport.width - 32, f:getWidth(label) + 28)
    local x, y = 16, viewport.height - 36
    love.graphics.push("all")
    love.graphics.origin()
    Theme.setColor(theme.night)
    love.graphics.rectangle("fill", x, y, width, 24, 7)
    Theme.setColor(ok and theme.accent or theme.nightMuted)
    love.graphics.rectangle("fill", x, y, 5, 24, 7, 0, 0, 7)
    love.graphics.setFont(f)
    Theme.setColor(theme.nightText)
    love.graphics.print(label, x + 14, y + 6)
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
    drawDiagnostics = drawDiagnostics,
    hitTest = hitTest,
  }
end
