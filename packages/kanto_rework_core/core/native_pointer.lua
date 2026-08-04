-- Semantic pointer adapters for the official Gen1Recomp native UI.
--
-- The adapters never call private callbacks directly. They translate a
-- window-space pointer target into the 160x144 native UI canvas, update the
-- real screen selection, then inject the ordinary Game Boy A action through
-- mod.input. This preserves the screen's own sounds, stack transitions,
-- callbacks, mod hooks, and validation rules.
return function(deps)
  local mod = assert(deps.mod)
  local runtime = assert(deps.runtime)
  local presenter = assert(deps.presenter)

  local Native = {}

  local function game()
    return runtime.game
  end

  local function topState()
    local current = game()
    local stack = current and current.stack
    return stack and type(stack.top) == "function" and stack:top() or nil
  end

  local function isOverworld(state)
    local current = game()
    return state == nil or (current and current.overworld and state == current.overworld)
  end

  local function windowToCanvas(x, y)
    local viewport = runtime.viewport
    if not viewport then return nil end
    local gx = tonumber(viewport.gameX) or tonumber(viewport.x) or 0
    local gy = tonumber(viewport.gameY) or tonumber(viewport.y) or 0
    local gw = tonumber(viewport.gameWidth) or tonumber(viewport.width) or 0
    local gh = tonumber(viewport.gameHeight) or tonumber(viewport.height) or 0
    if gw <= 0 or gh <= 0 then return nil end
    if x < gx or y < gy or x > gx + gw or y > gy + gh then return nil end
    return (x - gx) * 160 / gw, (y - gy) * 144 / gh
  end

  local function tapA()
    mod.input:tap(game(), "a")
    return true
  end

  local function clampIndex(state, value, count)
    if count <= 0 then return false end
    state.index = math.max(1, math.min(count, value))
    if type(state.clampScroll) == "function" then state:clampScroll() end
    return true
  end

  local function looksLikeParty(state)
    if type(state) ~= "table" or type(state.index) ~= "number" then return false end
    if state.items ~= nil or state.rows ~= nil then return false end
    return type(state.bottomMessage) == "function"
      or state.subItems ~= nil
      or state.pickOnly ~= nil
      or state.tmhm ~= nil
      or state.onSwitch ~= nil
      or state.swapFrom ~= nil
      or state.softboiledFrom ~= nil
  end

  local function partyTarget(state, ux, uy)
    if state.heal then return nil end
    if state.submenu and type(state.subItems) == "table" then
      local n = #state.subItems
      if n <= 0 then return nil end
      local y0 = (17 - n * 2) * 8
      if ux < 72 or ux > 160 or uy < y0 or uy >= y0 + n * 16 then return nil end
      local row = math.floor((uy - y0) / 16) + 1
      return "subIndex", row, n
    end
    local current = game()
    local party = state.party or (current and current.save and current.save.party) or {}
    local count = #party
    if count <= 0 or ux < 0 or ux > 160 or uy < 0 or uy >= count * 16 then
      return nil
    end
    return "index", math.floor(uy / 16) + 1, count
  end

  local function looksLikeList(state)
    return type(state) == "table"
      and type(state.items) == "table"
      and type(state.rows) == "number"
      and state.startCloses == nil
      and (state.onChoose ~= nil or state.title ~= nil or state.footer ~= nil)
  end

  local function listTarget(state, ux, uy)
    if state.script or #state.items == 0 then return nil end
    local visible = math.max(0, math.floor(state.rows or 0))
    if ux < 0 or ux > 160 or uy < 16 or uy >= 16 + visible * 16 then return nil end
    local slot = math.floor((uy - 16) / 16) + 1
    local itemIndex = (state.scroll or 0) + slot
    if not state.items[itemIndex] then return nil end
    return "index", itemIndex, #state.items
  end

  local function looksLikeOptionRows(state)
    return type(state) == "table"
      and type(state.rows) == "table"
      and type(state.index) == "number"
      and state.items == nil
  end

  local function optionTarget(state, ux, uy)
    if ux < 0 or ux > 160 or uy < 0 or uy > 144 then return nil end
    if uy >= 128 then
      return "index", #state.rows + 1, #state.rows + 1
    end
    local slot = math.floor(uy / 32) + 1
    if slot < 1 or slot > 4 then return nil end
    local itemIndex = (state.scroll or 0) + slot
    if not state.rows[itemIndex] then return nil end
    return "index", itemIndex, #state.rows + 1
  end

  local function looksLikeBoxedMenu(state)
    return type(state) == "table"
      and type(state.items) == "table"
      and type(state.index) == "number"
      and type(state.tx) == "number"
      and type(state.ty) == "number"
      and type(state.tw) == "number"
      and type(state.th) == "number"
      and type(state.rowStep) == "number"
  end

  local function boxedMenuTarget(state, ux, uy)
    local count = #state.items
    if count <= 0 then return nil end
    local visible = state.maxVisible and math.min(state.maxVisible, count) or count
    local left, right = state.tx * 8, (state.tx + state.tw) * 8
    if ux < left or ux > right then return nil end
    local firstY = (state.ty + state.th - 2 - (visible - 1) * state.rowStep) * 8
    local step = state.rowStep * 8
    if step <= 0 then return nil end
    local row = math.floor((uy - firstY + step / 2) / step) + 1
    if row < 1 or row > visible then return nil end
    local rowY = firstY + (row - 1) * step
    if uy < rowY - step / 2 or uy > rowY + step / 2 then return nil end
    local itemIndex = (state.scroll or 0) + row
    if not state.items[itemIndex] then return nil end
    return "index", itemIndex, count
  end

  local function looksLikeSummary(state)
    return type(state) == "table"
      and state.mon ~= nil
      and (state.page == 1 or state.page == 2)
      and state.items == nil and state.rows == nil
  end

  local function targetAt(state, ux, uy)
    if looksLikeParty(state) then return partyTarget(state, ux, uy) end
    if looksLikeList(state) then return listTarget(state, ux, uy) end
    if looksLikeOptionRows(state) then return optionTarget(state, ux, uy) end
    if looksLikeBoxedMenu(state) then return boxedMenuTarget(state, ux, uy) end
    if looksLikeSummary(state) and ux >= 0 and ux <= 160 and uy >= 0 and uy <= 144 then
      return "advance", 1, 1
    end
    return nil
  end

  local function applyTarget(state, field, value, count, activate)
    if field == "advance" then
      return activate and tapA() or true
    end
    if field == "subIndex" then
      state.subIndex = math.max(1, math.min(count, value))
    elseif field == "index" then
      if not clampIndex(state, value, count) then return false end
    else
      return false
    end
    if activate then return tapA() end
    return true
  end

  function Native.hover(x, y)
    local state = topState()
    if isOverworld(state) then return false end
    local supported = presenter.isSupportedStartMenu(game())
    if supported then return false end
    local ux, uy = windowToCanvas(x, y)
    if not ux then return false end
    local field, value, count = targetAt(state, ux, uy)
    if not field or field == "advance" then return false end
    return applyTarget(state, field, value, count, false)
  end

  function Native.activate(x, y)
    local state = topState()
    if isOverworld(state) then return false end
    local supported = presenter.isSupportedStartMenu(game())
    if supported then return false end
    local ux, uy = windowToCanvas(x, y)
    if not ux then return false end
    local field, value, count = targetAt(state, ux, uy)
    if not field then return false end
    return applyTarget(state, field, value, count, true)
  end

  function Native.wheel(dy)
    if dy == 0 then return false end
    local state = topState()
    if isOverworld(state) then return false end
    local supported = presenter.isSupportedStartMenu(game())
    if supported then return false end

    local delta = dy > 0 and -1 or 1
    if looksLikeParty(state) then
      if state.submenu and type(state.subItems) == "table" and #state.subItems > 0 then
        local n = #state.subItems
        state.subIndex = ((state.subIndex or 1) - 1 + delta) % n + 1
        return true
      end
      local current = game()
      local party = state.party or (current and current.save and current.save.party) or {}
      if #party > 0 then
        state.index = ((state.index or 1) - 1 + delta) % #party + 1
        return true
      end
    elseif looksLikeList(state) and #state.items > 0 then
      state.index = math.max(1, math.min(#state.items, (state.index or 1) + delta))
      if state.index - (state.scroll or 0) > state.rows then
        state.scroll = state.index - state.rows
      elseif state.index - (state.scroll or 0) < 1 then
        state.scroll = state.index - 1
      end
      return true
    elseif looksLikeOptionRows(state) then
      local count = #state.rows + 1
      state.index = ((state.index or 1) - 1 + delta) % count + 1
      return true
    elseif looksLikeBoxedMenu(state) and #state.items > 0 then
      state.index = ((state.index or 1) - 1 + delta) % #state.items + 1
      if type(state.clampScroll) == "function" then state:clampScroll() end
      return true
    end
    return false
  end

  function Native.kind()
    local state = topState()
    if looksLikeParty(state) then return "party" end
    if looksLikeList(state) then return "list" end
    if looksLikeOptionRows(state) then return "options" end
    if looksLikeBoxedMenu(state) then return "menu" end
    if looksLikeSummary(state) then return "summary" end
    return nil
  end

  return Native
end
