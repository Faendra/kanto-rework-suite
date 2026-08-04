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

local overworld = { screenId = "Overworld" }
local game = {
  overworld = overworld,
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
    states = { overworld, startMenu },
    top = function(self) return self.states[#self.states] end,
  },
}
local viewport = {
  width = 1920, height = 1080,
  gameX = 0, gameY = 0, gameWidth = 1200, gameHeight = 1080,
}
local function windowPoint(ux, uy)
  return viewport.gameX + ux / 160 * viewport.gameWidth,
         viewport.gameY + uy / 144 * viewport.gameHeight
end
local function clickCanvas(ux, uy, button)
  mouseX, mouseY = windowPoint(ux, uy)
  love.mousemoved(mouseX, mouseY, 0, 0, false)
  love.mousepressed(mouseX, mouseY, button or 1, false, 1)
end

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

-- Native PartyMenu: hovering selects the real slot, clicking injects A.
local partyScreen = {
  screenId = "PartyMenu",
  index = 1,
  bottomMessage = function() return "Choose a POKéMON." end,
}
game.stack.states = { overworld, partyScreen }
hooks["render.hud"](function() end, game, viewport)
local before = clearCount
hooks["render.compose"](function() return false end, {}, { uiCanvas = {} })
check(clearCount == before, "native party keeps native UI")
local tapsBeforeParty = #taps
clickCanvas(40, 24, 1)
check(partyScreen.index == 2, "party hover/click selects second party slot")
check(#taps == tapsBeforeParty + 1 and taps[#taps] == "a",
  "party left click activates through native A")
local tapsBeforePartyBack = #taps
clickCanvas(40, 24, 2)
check(#taps == tapsBeforePartyBack + 1 and taps[#taps] == "b",
  "right click backs out of a native fallback screen")

-- Party submenu uses its actual lower-right geometry.
partyScreen.submenu = true
partyScreen.subItems = { { label = "STATS" }, { label = "SWITCH" }, { label = "CANCEL" } }
partyScreen.subIndex = 1
local submenuY0 = (17 - #partyScreen.subItems * 2) * 8
local tapsBeforeSubmenu = #taps
clickCanvas(100, submenuY0 + 16 + 8, 1)
check(partyScreen.subIndex == 2, "party submenu click selects second command")
check(#taps == tapsBeforeSubmenu + 1 and taps[#taps] == "a",
  "party submenu click activates native A")
partyScreen.submenu, partyScreen.subItems = nil, nil

-- Native ListMenu contract used by Bag, Pokédex, shops and PC lists.
local listScreen = {
  title = "BAG", items = { { label = "POTION" }, { label = "ANTIDOTE" },
                            { label = "ESCAPE ROPE" } },
  rows = 7, index = 1, scroll = 0, onChoose = function() end,
}
game.stack.states = { overworld, listScreen }
hooks["render.hud"](function() end, game, viewport)
local tapsBeforeList = #taps
clickCanvas(80, 56, 1) -- third row: 16 + (3-1)*16 .. +16
check(listScreen.index == 3, "list click selects the visible native row")
check(#taps == tapsBeforeList + 1 and taps[#taps] == "a",
  "list click activates native A")

-- OptionRows contract used by Options and per-mod option screens.
local optionScreen = {
  rows = { { id = "one" }, { id = "two" }, { id = "three" },
           { id = "four" }, { id = "five" } },
  index = 1, scroll = 0,
}
game.stack.states = { overworld, optionScreen }
hooks["render.hud"](function() end, game, viewport)
local tapsBeforeOption = #taps
clickCanvas(80, 72, 1) -- third 32px option box
check(optionScreen.index == 3, "option click selects third option row")
check(#taps == tapsBeforeOption + 1 and taps[#taps] == "a",
  "option click activates native A")
clickCanvas(80, 136, 1)
check(optionScreen.index == #optionScreen.rows + 1,
  "option footer click selects CANCEL")

-- Generic boxed Menu contract used by choices and action submenus.
local boxed = {
  items = { { label = "YES" }, { label = "NO" } },
  index = 1, scroll = 0, startCloses = false,
  tx = 10, ty = 8, tw = 10, th = 6, rowStep = 2,
  clampScroll = function() end,
}
game.stack.states = { overworld, boxed }
hooks["render.hud"](function() end, game, viewport)
local tapsBeforeBoxed = #taps
clickCanvas(120, 96, 1)
check(boxed.index == 2, "boxed menu click selects second choice")
check(#taps == tapsBeforeBoxed + 1 and taps[#taps] == "a",
  "boxed menu click activates native A")

-- Summary is a single-action two-page state: left click advances exactly as A.
local summary = { mon = {}, page = 1 }
game.stack.states = { overworld, summary }
hooks["render.hud"](function() end, game, viewport)
local tapsBeforeSummary = #taps
clickCanvas(80, 72, 1)
check(#taps == tapsBeforeSummary + 1 and taps[#taps] == "a",
  "summary left click advances through native A")

-- Native wheel navigation also follows the active screen contract.
game.stack.states = { overworld, listScreen }
listScreen.index = 1
mouseX, mouseY = windowPoint(80, 24)
love.wheelmoved(0, -1)
check(listScreen.index == 2, "wheel navigates native list")

-- Pointer actions must remain inert in the ordinary overworld.
game.stack.states = { overworld }
local tapsBeforeWorldClick = #taps
clickCanvas(80, 72, 2)
clickCanvas(80, 72, 1)
check(#taps == tapsBeforeWorldClick,
  "left and right click do not inject actions in the overworld")

print("P0 runtime smoke passed")
