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
local game

local function font(size)
  return {
    getHeight = function() return math.max(10, math.floor(tonumber(size) or 12)) end,
    getWidth = function(_, value)
      return #tostring(value or "") * math.max(6, (tonumber(size) or 12) * 0.55)
    end,
  }
end
local currentFont = font(12)

local function dispatchPointer(ev)
  local hook = hooks["input.pointer"]
  if not hook or not game then return false end
  return hook(function() return false end, game, ev)
end

-- These three callbacks stand in for current Gen1Recomp Game:mouse* routing.
-- Kanto Rework wraps them only as a pre-#807 compatibility bridge, calls them
-- first, then verifies that the official hook fired before considering fallback.
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
  mousepressed = function(x, y, button, istouch)
    if istouch then return end
    return dispatchPointer({
      phase = "pressed", source = "mouse", id = "mouse",
      x = x, y = y, dx = 0, dy = 0, button = button,
    })
  end,
  mousemoved = function(x, y, dx, dy, istouch)
    if istouch then return end
    return dispatchPointer({
      phase = "moved", source = "mouse", id = "mouse",
      x = x, y = y, dx = dx or 0, dy = dy or 0,
    })
  end,
  mousereleased = function(x, y, button, istouch)
    if istouch then return end
    return dispatchPointer({
      phase = "released", source = "mouse", id = "mouse",
      x = x, y = y, dx = 0, dy = 0, button = button,
    })
  end,
}

local menuClass = {}
menuClass.__index = menuClass

local mod = {
  id = "kanto_rework_core",
  path = packageDir,
  hooks = { wrap = function(_, name, callback) hooks[name] = callback end },
  events = { on = function(_, name, callback) events[name] = callback end },
  options = {
    define = function(_, schema)
      for _, row in ipairs(schema) do optionValues[row.key] = row.default end
    end,
    get = function(_, key) return optionValues[key] end,
  },
  ui = { Menu = menuClass },
  input = { tap = function(_, _, button) taps[#taps + 1] = button end },
  log = { info = function() end, warn = function() end, error = function() end },
  exports = {},
}

local installer, loadError = loadfile(packageDir .. "/main.lua")
check(installer, loadError)
installer = installer()
check(type(installer) == "function", "entry must return installer")
installer(mod)

for _, name in ipairs({
  "input.pointer", "input.step", "render.zones", "render.compose", "render.hud",
}) do
  check(type(hooks[name]) == "function", name .. " hook registered")
end
check(type(events["game.ready"]) == "function", "game.ready listener registered")

local startMenu = setmetatable({
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
game = {
  overworld = overworld,
  save = {
    player = { name = "RED", map = "CELADON_MART" },
    party = { {}, {}, {} },
    money = 107207,
    playTime = 22 * 3600 + 54 * 60,
    pokedex = { owned = { a = true }, seen = { a = true, b = true } },
  },
  data = { maps = { CELADON_MART = { name = "CELADON MART" } } },
  stack = {
    states = { overworld, startMenu },
    top = function(self) return self.states[#self.states] end,
  },
}
local viewport = {
  width = 1920, height = 1080,
  gameX = 600, gameY = 0, gameWidth = 1200, gameHeight = 1080,
}
local function windowPoint(ux, uy)
  return viewport.gameX + ux / 160 * viewport.gameWidth,
         viewport.gameY + uy / 144 * viewport.gameHeight
end
local function moveCanvas(ux, uy)
  local oldX, oldY = mouseX, mouseY
  mouseX, mouseY = windowPoint(ux, uy)
  love.mousemoved(mouseX, mouseY, mouseX - oldX, mouseY - oldY, false)
end
local function clickWindow(x, y, button)
  mouseX, mouseY = x, y
  love.mousemoved(x, y, 0, 0, false)
  love.mousepressed(x, y, button or 1, false, 1)
  love.mousereleased(x, y, button or 1, false, 1)
end
local function clickCanvas(ux, uy, button)
  local x, y = windowPoint(ux, uy)
  clickWindow(x, y, button)
end
local function render()
  hooks["render.hud"](function() end, game, viewport)
end

events["game.ready"]({ game = game })
hooks["render.zones"](function(_, zones) return zones end, game, {})
render()
check(mod.exports.diagnostics().presenterReady == true,
  "screenId-less released Start menu is presented")
hooks["render.compose"](function() return false end, {}, { uiCanvas = {} })
check(clearCount == 1, "native UI clears only after presenter success")

local runtime = _G.__KANTO_REWORK_CORE_P0
check(runtime and runtime.startMenu and #runtime.startMenu.regions > 0,
  "presenter publishes Start-menu regions")
check(runtime.pointerHookSequence == 0, "official pointer sequence starts empty")
local first = runtime.startMenu.regions[1]
local beforeStart = #taps
clickWindow(first.x + first.w / 2, first.y + first.h / 2, 1)
check(#taps == beforeStart + 1 and taps[#taps] == "a",
  "Start-menu click injects one A through the official hook")
check(runtime.pointerHookSequence == 3,
  "press/move/release each arrived once; compatibility bridge did not duplicate")
clickWindow(first.x + first.w / 2, first.y + first.h / 2, 2)
check(taps[#taps] == "b", "Start-menu right click injects B on release")

local party = { index = 1, bottomMessage = function() return "Choose." end }
game.stack.states = { overworld, party }
render()
clickCanvas(40, 24, 1)
check(party.index == 2 and taps[#taps] == "a", "Party row click selects and activates")

party.submenu = true
party.subItems = { { label = "STATS" }, { label = "SWITCH" }, { label = "CANCEL" } }
party.subIndex = 1
local submenuY0 = (17 - #party.subItems * 2) * 8
clickCanvas(100, submenuY0 + 24, 1)
check(party.subIndex == 2 and taps[#taps] == "a", "Party submenu click selects and activates")

local list = {
  title = "BAG", rows = 7, index = 1, scroll = 0,
  items = { { label = "POTION" }, { label = "ANTIDOTE" }, { label = "ROPE" } },
  onChoose = function() end,
}
game.stack.states = { overworld, list }
render()
clickCanvas(80, 56, 1)
check(list.index == 3 and taps[#taps] == "a", "List row click selects and activates")
local beforeBlankList = #taps
clickCanvas(80, 140, 1)
check(#taps == beforeBlankList, "blank structured-menu space does not confirm old selection")

local options = {
  rows = { { id = "one" }, { id = "two" }, { id = "three" }, { id = "four" } },
  index = 1, scroll = 0,
}
game.stack.states = { overworld, options }
render()
clickCanvas(80, 72, 1)
check(options.index == 3 and taps[#taps] == "a", "Options row click selects and activates")

local boxed = {
  items = { { label = "USE" }, { label = "CANCEL" } }, index = 1, scroll = 0,
  startCloses = false, tx = 10, ty = 8, tw = 10, th = 6, rowStep = 2,
  clampScroll = function() end,
}
game.stack.states = { overworld, boxed }
render()
clickCanvas(120, 96, 1)
check(boxed.index == 2 and taps[#taps] == "a", "Boxed menu click selects and activates")

local dialogue = {
  pages = { { "Hello" } }, pageIndex = 1, shown = {},
  boxTx = 0, boxTy = 12, boxTw = 20, boxTh = 6,
}
game.stack.states = { overworld, dialogue }
render()
local beforeDialogue = #taps
clickCanvas(80, 120, 1)
check(#taps == beforeDialogue + 1 and taps[#taps] == "a", "Dialogue click advances")

local choice = {
  index = 1, onChoose = function() end,
  tx = 13, ty = 6, tw = 7, th = 6,
}
game.stack.states = { overworld, choice }
render()
local beforeChoice = #taps
clickCanvas(136, 72, 1)
check(choice.index == 2, "Choice click selects NO")
check(#taps == beforeChoice + 1 and taps[#taps] == "a", "Choice click confirms through A")
clickCanvas(136, 72, 2)
check(taps[#taps] == "b", "Choice right click cancels through B")

-- Native wheel behavior remains available outside input.pointer.
game.stack.states = { overworld, list }
list.index = 1
render()
moveCanvas(80, 24)
love.wheelmoved(0, -1)
check(list.index == 2, "Wheel navigates native list")

-- Exact overworld identity and wrapped/unknown world states both fall back to A.
game.stack.states = { overworld }
render()
local beforeWorld = #taps
clickCanvas(80, 72, 1)
clickCanvas(80, 72, 2)
check(#taps == beforeWorld + 2, "Overworld accepts left and right click")
check(taps[#taps - 1] == "a" and taps[#taps] == "b",
  "Overworld maps left to A and right to B")

local wrappedWorld = { screenId = "WrappedOverworld" }
game.stack.states = { wrappedWorld }
render()
local beforeWrapped = #taps
clickCanvas(80, 72, 1)
check(#taps == beforeWrapped + 1 and taps[#taps] == "a",
  "unknown live world wrapper still receives native A")

-- Left click outside the game viewport remains inert.
local beforeBar = #taps
clickWindow(20, 200, 1)
check(#taps == beforeBar, "window bars do not trigger overworld A")

-- Overlay owns its rectangle for both buttons and cannot click through.
game.stack.states = { overworld }
render()
local overlay = runtime.overlayRegion
check(overlay ~= nil, "overlay region is available")
local beforeOverlay = #taps
clickWindow(overlay.x + overlay.w / 2, overlay.y + overlay.h / 2, 1)
clickWindow(overlay.x + overlay.w / 2, overlay.y + overlay.h / 2, 2)
check(#taps == beforeOverlay, "locked overlay consumes pointer actions")

-- A cancelled official pointer lifecycle never activates.
local x, y = windowPoint(80, 72)
local beforeCancel = #taps
dispatchPointer({ phase = "pressed", source = "touch", id = 99, x = x, y = y })
dispatchPointer({ phase = "cancelled", source = "touch", id = 99, x = x, y = y })
check(#taps == beforeCancel, "cancelled pointer does not inject A")

print("P0 runtime smoke passed")
