return function(deps)
  local mod = assert(deps.mod)
  local runtime = assert(deps.runtime)
  local presenter = assert(deps.presenter)
  local Layout = assert(deps.Layout)
  local persist = assert(deps.persist)

  local nativeChunk, nativeError = love.filesystem.load(
    mod.path .. "/core/native_pointer.lua")
  assert(nativeChunk, nativeError or "Unable to load native pointer adapters")
  local createNativePointer = nativeChunk()
  local native = createNativePointer({
    mod = mod,
    runtime = runtime,
    presenter = presenter,
  })
  runtime.nativePointer = native

  local function game()
    return runtime.game
  end

  local function supportedMenu()
    return presenter.isSupportedStartMenu(game())
  end

  local function hasTopState()
    local current = game()
    local stack = current and current.stack
    return stack and type(stack.top) == "function" and stack:top() ~= nil
  end

  local function updateHover(x, y)
    runtime.pointerX, runtime.pointerY = x, y
    runtime.hoveredItem = nil
    local region = presenter.hitTest(x, y)
    if region and region.kind == "menu_row" then
      runtime.hoveredItem = region.itemIndex
    end
    return region
  end

  local function selectRow(region, activate)
    local ok, state = supportedMenu()
    if not ok or not region or region.kind ~= "menu_row" then return false end
    state.index = math.max(1, math.min(#state.items, region.itemIndex))
    if state.clampScroll then state:clampScroll() end
    if activate then mod.input:tap(game(), "a") end
    return true
  end

  local function beginDrag(region, x, y)
    if not runtime.editMode or runtime.profile.widgetLocked then return false end
    if not region or region.kind ~= "overlay" then return false end
    if y > region.y + region.headerH then return false end
    runtime.drag = {
      offsetX = x - region.x,
      offsetY = y - region.y,
      width = region.w,
      height = region.h,
    }
    return true
  end

  local function dragTo(x, y)
    local drag = runtime.drag
    local viewport = runtime.viewport
    if not drag or not viewport then return false end
    local safe = Layout.safeArea(viewport)
    local targetX = math.max(safe.x, math.min(safe.x + safe.w - drag.width,
      x - drag.offsetX))
    local targetY = math.max(safe.y, math.min(safe.y + safe.h - drag.height,
      y - drag.offsetY))
    runtime.profile.widgetX, runtime.profile.widgetY = Layout.windowToNormalized(
      targetX, targetY, viewport, drag.width, drag.height)
    return true
  end

  local function endDrag()
    if not runtime.drag then return false end
    runtime.drag = nil
    persist()
    return true
  end

  local function install()
    local global = runtime.global
    if global.pointerInstalled then return end
    global.pointerInstalled = true
    global.original = global.original or {}

    global.original.mousepressed = love.mousepressed
    love.mousepressed = function(x, y, button, istouch, presses)
      local r = _G.__KANTO_REWORK_CORE_P0
      if r and r.handlers and r.handlers.mousepressed
          and r.handlers.mousepressed(x, y, button, istouch, presses) then
        return
      end
      local original = r and r.global and r.global.original.mousepressed
      if original then return original(x, y, button, istouch, presses) end
    end

    global.original.mousereleased = love.mousereleased
    love.mousereleased = function(x, y, button, istouch, presses)
      local r = _G.__KANTO_REWORK_CORE_P0
      if r and r.handlers and r.handlers.mousereleased
          and r.handlers.mousereleased(x, y, button, istouch, presses) then
        return
      end
      local original = r and r.global and r.global.original.mousereleased
      if original then return original(x, y, button, istouch, presses) end
    end

    global.original.mousemoved = love.mousemoved
    love.mousemoved = function(x, y, dx, dy, istouch)
      local r = _G.__KANTO_REWORK_CORE_P0
      if r and r.handlers and r.handlers.mousemoved then
        r.handlers.mousemoved(x, y, dx, dy, istouch)
      end
      local original = r and r.global and r.global.original.mousemoved
      if original then return original(x, y, dx, dy, istouch) end
    end

    global.original.wheelmoved = love.wheelmoved
    love.wheelmoved = function(dx, dy)
      local r = _G.__KANTO_REWORK_CORE_P0
      if r and r.handlers and r.handlers.wheelmoved
          and r.handlers.wheelmoved(dx, dy) then
        return
      end
      local original = r and r.global and r.global.original.wheelmoved
      if original then return original(dx, dy) end
    end

    global.original.touchpressed = love.touchpressed
    love.touchpressed = function(id, x, y, dx, dy, pressure)
      local r = _G.__KANTO_REWORK_CORE_P0
      if r and r.handlers and r.handlers.touchpressed
          and r.handlers.touchpressed(id, x, y, dx, dy, pressure) then
        return
      end
      local original = r and r.global and r.global.original.touchpressed
      if original then return original(id, x, y, dx, dy, pressure) end
    end

    global.original.touchmoved = love.touchmoved
    love.touchmoved = function(id, x, y, dx, dy, pressure)
      local r = _G.__KANTO_REWORK_CORE_P0
      if r and r.handlers and r.handlers.touchmoved then
        r.handlers.touchmoved(id, x, y, dx, dy, pressure)
      end
      local original = r and r.global and r.global.original.touchmoved
      if original then return original(id, x, y, dx, dy, pressure) end
    end

    global.original.touchreleased = love.touchreleased
    love.touchreleased = function(id, x, y, dx, dy, pressure)
      local r = _G.__KANTO_REWORK_CORE_P0
      if r and r.handlers and r.handlers.touchreleased
          and r.handlers.touchreleased(id, x, y, dx, dy, pressure) then
        return
      end
      local original = r and r.global and r.global.original.touchreleased
      if original then return original(id, x, y, dx, dy, pressure) end
    end

    global.original.keypressed = love.keypressed
    love.keypressed = function(key, scancode, isrepeat)
      local r = _G.__KANTO_REWORK_CORE_P0
      if r and r.handlers and r.handlers.keypressed
          and r.handlers.keypressed(key, scancode, isrepeat) then
        return
      end
      local original = r and r.global and r.global.original.keypressed
      if original then return original(key, scancode, isrepeat) end
    end

    global.original.gamepadpressed = love.gamepadpressed
    love.gamepadpressed = function(joystick, button)
      local r = _G.__KANTO_REWORK_CORE_P0
      if r and r.handlers and r.handlers.gamepadpressed then
        r.handlers.gamepadpressed(joystick, button)
      end
      local original = r and r.global and r.global.original.gamepadpressed
      if original then return original(joystick, button) end
    end
  end

  runtime.handlers = runtime.handlers or {}
  runtime.handlers.mousepressed = function(x, y, button, istouch)
    if istouch then return false end
    runtime.lastInput = "mouse"
    local region = updateHover(x, y)

    -- The companion overlay owns its rectangle. Even while locked, pointer
    -- presses on it must never interact with an NPC or menu underneath.
    if region and region.kind == "overlay" then
      if button == 1 and beginDrag(region, x, y) then return true end
      return true
    end

    -- Right click is the global B/Cancel action, including the overworld.
    -- ChoiceBox already maps B to NO, so dialogue choices retain native
    -- behavior rather than receiving a custom callback path.
    if button == 2 and hasTopState() then
      if not native.isOverworld() or native.inGameViewport(x, y) then
        mod.input:tap(game(), "b")
        return true
      end
      return false
    end

    if button ~= 1 then return false end
    if beginDrag(region, x, y) then return true end
    if selectRow(region, true) then return true end
    if native.activate(x, y) then return true end

    -- In the live overworld, left click is the native A action: talk to the
    -- facing NPC, inspect a sign/object, or trigger any ordinary interaction.
    if native.isOverworld() and native.inGameViewport(x, y) then
      mod.input:tap(game(), "a")
      return true
    end
    return false
  end

  runtime.handlers.mousereleased = function(_, _, button)
    if button == 1 then return endDrag() end
    return false
  end

  runtime.handlers.mousemoved = function(x, y)
    runtime.lastInput = "mouse"
    local region = updateHover(x, y)
    if not region then native.hover(x, y) end
    dragTo(x, y)
  end

  runtime.handlers.wheelmoved = function(_, dy)
    runtime.lastInput = "mouse"
    local x, y = love.mouse.getPosition()
    local region = updateHover(x, y)
    local ok, state = supportedMenu()
    if ok and region and region.kind == "menu_row" and dy ~= 0 then
      local delta = dy > 0 and -1 or 1
      state.index = math.max(1, math.min(#state.items, state.index + delta))
      if state.clampScroll then state:clampScroll() end
      return true
    end
    if region and region.kind == "overlay" then return true end
    return native.wheel(dy)
  end

  runtime.handlers.touchpressed = function(id, x, y)
    runtime.lastInput = "touch"
    runtime.touchId = id
    local region = updateHover(x, y)
    if region and region.kind == "overlay" then
      if beginDrag(region, x, y) then return true end
      return true
    end
    if selectRow(region, true) then return true end
    return native.activate(x, y)
  end

  runtime.handlers.touchmoved = function(id, x, y)
    if runtime.touchId ~= id then return end
    runtime.lastInput = "touch"
    local region = updateHover(x, y)
    if not region then native.hover(x, y) end
    dragTo(x, y)
  end

  runtime.handlers.touchreleased = function(id)
    if runtime.touchId ~= id then return false end
    runtime.touchId = nil
    return endDrag()
  end

  runtime.handlers.keypressed = function(key)
    runtime.lastInput = "keyboard"
    if key == "f8" then
      runtime.profile.overlayVisible = not runtime.profile.overlayVisible
      persist()
      return true
    end
    if key == "f9" then
      runtime.editMode = not runtime.editMode
      return true
    end
    if key == "escape" and runtime.editMode then
      runtime.editMode = false
      runtime.drag = nil
      return true
    end
    return false
  end

  runtime.handlers.gamepadpressed = function()
    runtime.lastInput = "controller"
  end

  install()
end
