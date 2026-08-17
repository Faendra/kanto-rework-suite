return function(mod)
  local function loadModule(relative)
    local path = mod.path .. "/" .. relative
    local chunk, err = love.filesystem.load(path)
    assert(chunk, err or ("Unable to load " .. path))
    return chunk()
  end

  local Layout = loadModule("core/layout.lua")
  local Theme = loadModule("core/theme.lua")
  local createProfileStore = loadModule("core/profile.lua")
  local createPresenter = loadModule("core/presenter.lua")
  local createPointer = loadModule("core/pointer.lua")

  mod.options:define({
    { key = "replace_start_menu", label = "REPLACE START MENU", type = "toggle",
      default = true,
      description = "Replace the released Start menu with the Field Journal presenter." },
    { key = "overlay", label = "COMPANION OVERLAY", type = "toggle",
      default = true,
      description = "Show the movable P0 trainer companion card outside the Start menu." },
    { key = "theme", label = "UI THEME", type = "choice",
      default = "field_journal",
      choices = {
        { "FIELD JOURNAL", "field_journal" },
        { "GRAPHITE", "graphite" },
      },
      description = "Switch the live vector design tokens used by the P0 interface." },
    { key = "diagnostics", label = "P0 DIAGNOSTIC BADGE", type = "toggle",
      default = true,
      description = "Show the render-hook and Start-menu detection state for this test build." },
  })

  local global = _G.__KANTO_REWORK_CORE_P0 or { original = {} }
  _G.__KANTO_REWORK_CORE_P0 = global
  global.global = global
  global.mod = mod
  global.lastInput = global.lastInput or "keyboard"
  global.editMode = global.editMode or false
  global.hoveredItem = nil
  global.startMenu = nil
  global.overlayRegion = nil
  global.viewport = global.viewport or { width = 1920, height = 1080 }
  global.presenterReady = false
  global.presenterError = nil
  global.loggedPresenterError = nil

  local profileStore = createProfileStore({
    path = "kanto_rework/profiles/p0_default.lua",
    defaults = {
      theme = mod.options:get("theme") or "field_journal",
      overlayVisible = true,
      widgetLocked = false,
      widgetX = 0.04,
      widgetY = 0.08,
    },
  })

  local profile, profileError = profileStore.load()
  global.profile = profile
  if profileError then mod.log:warn("profile fallback: %s", tostring(profileError)) end

  local function persist()
    local ok, err = profileStore.save(global.profile)
    if not ok then mod.log:warn("profile save failed: %s", tostring(err)) end
    return ok
  end

  local presenter = createPresenter({
    Layout = Layout,
    Theme = Theme,
    runtime = global,
    MenuClass = mod.ui and mod.ui.Menu,
  })
  global.presenter = presenter

  createPointer({
    mod = mod,
    runtime = global,
    presenter = presenter,
    Layout = Layout,
    persist = persist,
  })

  local function logPresenterError(err)
    local value = tostring(err)
    global.presenterError = value
    if global.loggedPresenterError ~= value then
      global.loggedPresenterError = value
      mod.log:error("presenter failed; native UI retained: %s", value)
    end
  end

  local function drawEmergencyNotice(viewport, message)
    if not (love and love.graphics and viewport) then return end
    local width = tonumber(viewport.width) or 640
    local height = tonumber(viewport.height) or 360
    local boxW = math.min(760, math.max(320, width - 48))
    local boxH = 118
    local x = (width - boxW) / 2
    local y = math.max(24, height - boxH - 52)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setColor(0.10, 0.025, 0.035, 0.97)
    love.graphics.rectangle("fill", x, y, boxW, boxH, 12)
    love.graphics.setColor(0.96, 0.28, 0.25, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, boxW, boxH, 12)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Kanto Rework presenter error — native UI kept visible", x + 18, y + 16)
    love.graphics.setColor(0.90, 0.84, 0.84, 1)
    love.graphics.printf(tostring(message), x + 18, y + 48, boxW - 36, "left")
    love.graphics.pop()
  end

  mod.events:on("game.ready", function(payload)
    global.game = payload and payload.game or global.game
  end)

  mod.events:on("mod.options_changed", function(payload)
    if not payload or payload.mod ~= mod.id then return end
    if payload.key == "theme" and type(payload.value) == "string" then
      global.profile.theme = payload.value
      persist()
    end
  end)

  mod.hooks:wrap("input.step", function(next, game, dt)
    global.game = game
    return next(game, dt)
  end, 120)

  -- render.compose has no Game parameter. The released engine calls
  -- render.zones immediately before it, so cache the exact live singleton.
  mod.hooks:wrap("render.zones", function(next, game, zones)
    global.game = game
    return next(game, zones)
  end, 120)

  -- Preserve the native menu until the presenter has completed at least one
  -- frame. On following frames clear only the classic UI canvas; the world,
  -- post-processing, palette zones and external render pipeline stay owned by
  -- the engine.
  mod.hooks:wrap("render.compose", function(next, renderer, ctx)
    local handled = next(renderer, ctx)
    if handled == true or mod.options:get("replace_start_menu") == false then
      return handled
    end
    local supported = presenter.isSupportedStartMenu(global.game)
    if supported and global.presenterReady
        and love and love.graphics and ctx and ctx.uiCanvas then
      love.graphics.push("all")
      love.graphics.setCanvas(ctx.uiCanvas)
      love.graphics.clear(0, 0, 0, 0)
      love.graphics.pop()
    end
    return handled
  end, 120)

  -- render.hud is the released full-window presentation seam. It runs after
  -- the engine composite and before touch controls, matching Gen1 Modern UI's
  -- proven ownership model while leaving native state/input callbacks intact.
  mod.hooks:wrap("render.hud", function(next, game, viewport)
    global.game = game
    next(game, viewport)
    if not (love and love.graphics and viewport) then
      global.presenterReady = false
      return
    end

    global.viewport = viewport
    global.startMenu = nil
    global.overlayRegion = nil
    global.presenterReady = false
    global.presenterError = nil
    global.profile.theme = mod.options:get("theme") or global.profile.theme

    if mod.options:get("replace_start_menu") ~= false then
      local ok, drawn = pcall(presenter.drawStartMenu,
        game, viewport, global.profile)
      if ok then
        global.presenterReady = drawn == true
      else
        logPresenterError(drawn)
        drawEmergencyNotice(viewport, drawn)
      end
    end

    if mod.options:get("overlay") ~= false then
      local ok, err = pcall(presenter.drawOverlay,
        game, viewport, global.profile)
      if not ok then
        logPresenterError(err)
        drawEmergencyNotice(viewport, err)
      end
    end

    local ok, err = pcall(presenter.drawDiagnostics,
      game, viewport, global.profile,
      mod.options:get("diagnostics") ~= false)
    if not ok then logPresenterError(err) end
  end, 120)

  mod.exports.version = 4
  mod.exports.layoutClass = function(width, height)
    return Layout.classify(width, height)
  end
  mod.exports.profile = function()
    return {
      theme = global.profile.theme,
      overlayVisible = global.profile.overlayVisible,
      widgetLocked = global.profile.widgetLocked,
      widgetX = global.profile.widgetX,
      widgetY = global.profile.widgetY,
    }
  end
  mod.exports.diagnostics = function()
    local supported, state, reason = presenter.isSupportedStartMenu(global.game)
    return {
      hudActive = global.viewport ~= nil,
      presenterReady = global.presenterReady,
      presenterError = global.presenterError,
      startMenuSupported = supported,
      topScreenId = state and state.screenId or nil,
      supportReason = reason,
      viewport = global.viewport,
    }
  end
  mod.exports.isPointerExperimental = true

  mod.log:info("P0.0.4 loaded: released render.hud/compose contract, structural Start-menu detection")
end
