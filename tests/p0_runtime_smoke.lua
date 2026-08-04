local packageDir = assert(arg[1], "package directory argument required")

local function fail(message)
  error("P0 runtime smoke: " .. tostring(message), 0)
end
local function check(value, message)
  if not value then fail(message) end
end

local hooks, events, optionValues = {}, {}, {}
local taps = {}
local clearCount = 0
local mouseX, mouseY = 0, 0

local function font(size)
  return {
    getHeight = function() return math.max(10, math.floor(tonumber(size) or 12)) end,
    getWidth = function(_, value)
      return #tostring(value or "") * math.max(6, (tonumber(size) or 12) * 0.55)
    end,
  }
end
local currentFont = font(12)

love = {
  filesystem = {
    load = function(path) return loadfile(path) end,
    getInfo = function() return nil end,
    createDirectory = function() return true end,
    write = function() return true end,
  },
  graphics = {
    newFont = font,
    setFont = function(value) currentFont = value end,
    getFont = function() return currentFont end,
    setColor = function() end,
    setLineWidth = function() end,
    push = function() end,
    pop = function() end,
    origin = function() end,
    print = function() end,
    printf = function() end,
    polygon = function() end,
    rectangle = function(_, ...)
      check(select("#", ...) <= 7, "rectangle called with invalid argument count")
    end,
    setCanvas = function() end,
    clear = function() clearCount = clearCount + 1 end,
  },
  mouse = {
    getPosition = function() return mouseX, mouseY end,
  },
}

local menuClass = {}
menuClass.__index = menuClass

local mod = {
  id = "kanto_rework_core",
  path = packageDir,
  hooks = {
    wrap = function(_, name, callback) hooks[name] = callback end,
  },
  events = {
    on = function(_, name, callback) events[name] = callback end,
  },
  options = {
    define = function(_, schema)
      for _, row in ipairs(schema) do optionValues[row.key] = row.default end
    end,
    get = function(_, key) return optionValues[key] end,
  },
  ui = { Menu = menuClass },
  input = {
    tap = function(_, _, button) taps[#taps + 1] = button end,
  },
  log = {
    info = function() end,
    warn = function() end,
    error = function() end,
  },
  exports = {},
}

local installer, loadError = loadfile(packageDir .. "/main.lua")
check(installer, loadError)
installer = installer()
check(type(installer) == "function", "entry must return installer")
installer(mod)

for _, name in ipairs({ "input.step", "render.zones", "render.compose", "render.hud" }) do
  check(type(hooks[name]) == "function", name .. " hook registered")
end
check(type(events["game.ready"]) == "function", "game.ready listener registered")

local startMenu = setmetatable({
  -- Deliberately no screenId: this is the released StartMenu shape.
  items = {
    { label = "POKéDEX" }, { label = "POKéMON" }, { label = "ITEM" },
    { label = "RED" }, { label = "SAVE" }, { label = "OPTION" },
  },
  index = 1,
  scroll = 0,
  startCloses = true,
  clampScroll = function() end,
}, { __index = menuClass })

local game = {
  save = {
    player = { name = "RED", map = "CELADON_MART" },
    party = { {}, {}, {} },
    money = 107207,
    playTime = 22 * 3600 + 54 * 60,
    pokedex = {
      owned = { a = true, b = true },
      seen = { a = true, b = true, c = true },
    },
  },
  data = { maps = { CELADON_MART = { name = "CELADON MART" } } },
  stack = {
    states = { startMenu },
    top = function(self) return self.states[#self.states] end,
  },
}
local viewport = {
  width = 1920, height = 1080,
  gameX = 0, gameY = 0, gameWidth = 1200, gameHeight = 1080,
}

events["game.ready"]({ game = game })
hooks["render.zones"](function(_, zones) return zones end, game, {})
hooks["render.hud"](function() end, game, viewport)

local diagnostics = mod.exports.diagnostics()
check(diagnostics.presenterReady == true,
  "screenId-less released Start menu is presented")
check(diagnostics.startMenuSupported == true,
  "Start menu support reports true")

hooks["render.compose"](function() return false end, {}, { uiCanvas = {} })
check(clearCount == 1,
  "native UI canvas clears only after presenter success")

local runtime = _G.__KANTO_REWORK_CORE_P0
check(runtime and runtime.startMenu and #runtime.startMenu.regions > 0,
  "presenter publishes pointer hit regions")
local first = runtime.startMenu.regions[1]
mouseX, mouseY = first.x + first.w / 2, first.y + first.h / 2
love.mousemoved(mouseX, mouseY, 0, 0, false)
love.mousepressed(mouseX, mouseY, 1, false, 1)
check(taps[#taps] == "a", "left click activates through mod.input")
love.mousepressed(mouseX, mouseY, 2, false, 1)
check(taps[#taps] == "b", "right click returns through mod.input")

-- Native fallback: unknown non-menu state must not clear the canvas.
game.stack.states = { { screenId = "UnknownState" } }
hooks["render.hud"](function() end, game, viewport)
local before = clearCount
hooks["render.compose"](function() return false end, {}, { uiCanvas = {} })
check(clearCount == before, "unknown screen keeps native UI")

print("P0 runtime smoke passed")
