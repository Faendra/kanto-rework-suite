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
    { key = "replace_start_menu", label = "REPLACE START MENU", type = "toggle", default = true },
    { key = "overlay", label = "P0 OVERLAY", type = "toggle", default = true },
    { key = "theme", label = "THEME", type = "choice", default = "field_journal",
      choices = {
        { "FIELD JOURNAL", "field_journal" },
        { "GRAPHITE", "graphite" },
      } },
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

  local profileStore = createProfileStore({
    path = "kanto_rework/profiles/p0_default.lua",
    defaults = {
      theme = mod.options:get("theme") or "field_journal",
      overlayVisible = mod.options:get("overlay") ~= false,
      widgetLocked = false,
      widgetX = 0.04,
      widgetY = 0.08,
    },
  })

  local profile, profileError = profileStore.load()
  global.profile = profile
  if profileError then
    mod.log:warn("profile fallback: %s", tostring(profileError))
  end

  local function persist()
    local ok, err = profileStore.save(global.profile)
    if not ok then mod.log:warn("profile save failed: %s", tostring(err)) end
    return ok
  end

  local presenter = createPresenter({
    Layout = Layout,
    Theme = Theme,
    runtime = global,
  })
  global.presenter = presenter

  createPointer({
    mod = mod,
    runtime = global,
    presenter = presenter,
    Layout = Layout,
    persist = persist,
  })

  mod.events:on("game.ready", function(payload)
    global.game = payload and payload.game or global.game
  end)

  mod.events:on("mod.options_changed", function(payload)
    if not payload or payload.mod ~= mod.id then return end
    if payload.key == "theme" and type(payload.value) == "string" then
      global.profile.theme = payload.value
      persist()
    elseif payload.key == "overlay" then
      global.profile.overlayVisible = payload.value ~= false
      persist()
    end
  end)

  mod.hooks:wrap("input.step", function(next, game, dt)
    global.game = game
    return next(game, dt)
  end, 120)

  mod.hooks:wrap("render.zones", function(next, game, zones)
    global.game = game
    return next(game, zones)
  end, 120)

  mod.hooks:wrap("render.compose", function(next, renderer, ctx)
    local handled = next(renderer, ctx)
    if handled == true or mod.options:get("replace_start_menu") == false then
      return handled
    end
    local supported = presenter.isSupportedStartMenu(global.game)
    if supported and love and love.graphics and ctx and ctx.uiCanvas then
      love.graphics.push("all")
      love.graphics.setCanvas(ctx.uiCanvas)
      love.graphics.clear(0, 0, 0, 0)
      love.graphics.pop()
    end
    return handled
  end, 120)

  mod.hooks:wrap("render.hud", function(next, game, viewport)
    global.game = game
    next(game, viewport)
    if not (love and love.graphics and viewport) then return end
    global.viewport = viewport
    global.startMenu = nil
    global.overlayRegion = nil
    if mod.options:get("replace_start_menu") ~= false then
      presenter.drawStartMenu(game, viewport, global.profile)
    end
    if mod.options:get("overlay") ~= false then
      presenter.drawOverlay(viewport, global.profile)
    end
  end, 120)

  mod.exports.version = 1
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
  mod.exports.isPointerExperimental = true

  mod.log:info("P0 core loaded: F8 overlay, F9 edit overlay, mouse/touch start-menu presenter")
end
