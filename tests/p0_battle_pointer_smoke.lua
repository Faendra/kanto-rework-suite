local packageDir = assert(arg[1], "package directory argument required")

local function check(value, message)
  if not value then error("Battle pointer smoke: " .. tostring(message), 0) end
end

love = {
  filesystem = { load = function(path) return loadfile(path) end },
}

local taps = {}
local top
local game = {
  stack = { top = function() return top end },
}
local runtime = {
  game = game,
  viewport = {
    width = 1920, height = 1080,
    gameX = 640, gameY = 252,
    gameWidth = 640, gameHeight = 576,
    scale = 4, dpiX = 1, dpiY = 1,
  },
}
local mod = {
  input = {
    tap = function(_, currentGame, button)
      check(currentGame == game, "actions target the live Game object")
      taps[#taps + 1] = button
    end,
  },
}
local presenter = { isSupportedStartMenu = function() return false end }

local chunk, loadError = loadfile(packageDir .. "/core/native_pointer.lua")
check(chunk, loadError)
local native = chunk()({ mod = mod, runtime = runtime, presenter = presenter })

local function windowPoint(ux, uy, surfaceW, surfaceH)
  surfaceW, surfaceH = surfaceW or 160, surfaceH or 144
  return runtime.viewport.gameX + ux / surfaceW * runtime.viewport.gameWidth,
         runtime.viewport.gameY + uy / surfaceH * runtime.viewport.gameHeight
end

local function activateNative(ux, uy, surfaceW, surfaceH)
  local x, y = windowPoint(ux, uy, surfaceW, surfaceH)
  return native.activate(x, y)
end

local function hoverNative(ux, uy, surfaceW, surfaceH)
  local x, y = windowPoint(ux, uy, surfaceW, surfaceH)
  return native.hover(x, y)
end

local battle = {
  phase = "menu",
  menuIndex = 1,
  moveIndex = 1,
  player = { curMoves = { {}, {}, {}, {} } },
  enemy = {},
  wideLayout = function() return false end,
}
top = battle
check(native.kind() == "battle", "BattleState shape is detected")
check(hoverNative(88, 132) == true and battle.menuIndex == 3,
  "classic hover selects ITEM")
local before = #taps
check(activateNative(136, 132) == true and battle.menuIndex == 4,
  "classic click selects RUN")
check(#taps == before + 1 and taps[#taps] == "a",
  "classic command click confirms through A")
check(native.wheel(1) == true and battle.menuIndex == 3,
  "battle command wheel moves upward")
check(native.wheel(-1) == true and battle.menuIndex == 4,
  "battle command wheel moves downward")

battle.phase = "moveSelect"
battle.moveIndex = 1
before = #taps
check(hoverNative(80, 124) == true and battle.moveIndex == 3,
  "classic hover selects the third move row")
check(activateNative(80, 132) == true and battle.moveIndex == 4,
  "classic click selects the fourth move row")
check(#taps == before + 1 and taps[#taps] == "a",
  "classic move click confirms through A")
check(native.wheel(1) == true and battle.moveIndex == 3,
  "move-list wheel navigates")

battle.phase = "mimicSelect"
battle.mimicMoves = { {}, {}, {} }
battle.mimicIndex = 1
check(hoverNative(40, 76) == true and battle.mimicIndex == 2,
  "classic Mimic chooser selects its second row")

battle.phase = "messages"
before = #taps
check(activateNative(80, 120) == true,
  "battle message box accepts a click")
check(#taps == before + 1 and taps[#taps] == "a",
  "battle message click advances through A")

-- Wide battle uses the actual 304x144 native surface reported by the
-- Renderer viewport rather than pretending the frame is 160 pixels wide.
runtime.viewport.gameX = 352
runtime.viewport.gameY = 252
runtime.viewport.gameWidth = 1216
runtime.viewport.gameHeight = 576
battle.wideLayout = function() return true end
battle.phase = "menu"
battle.menuIndex = 1
check(hoverNative(260, 132, 304, 144) == true and battle.menuIndex == 4,
  "wide hover selects RUN in the lower-right command cell")
before = #taps
check(activateNative(180, 116, 304, 144) == true and battle.menuIndex == 1,
  "wide click selects FIGHT")
check(#taps == before + 1 and taps[#taps] == "a",
  "wide command click confirms through A")

battle.phase = "moveSelect"
battle.moveIndex = 1
check(hoverNative(150, 132, 304, 144) == true and battle.moveIndex == 4,
  "wide move grid selects the lower-right move")

-- A classic 160x144 native screen pushed over a wide battle is centred in
-- the 304-pixel surface. The adapter removes the 72-pixel side offset.
local list = {
  title = "BAG", rows = 7, index = 1, scroll = 0,
  items = { { label = "ONE" }, { label = "TWO" }, { label = "THREE" } },
  onChoose = function() end,
}
top = list
check(hoverNative(72 + 80, 56, 304, 144) == true and list.index == 3,
  "classic list over wide battle maps its centred coordinates")

-- ChoiceBox rows are selected by their actual rendered centres.
local choice = {
  index = 2, onChoose = function() end,
  tx = 13, ty = 6, tw = 7, th = 6,
}
top = choice
check(hoverNative(72 + 136, 60, 304, 144) == true and choice.index == 1,
  "centred YES row selects YES")
check(hoverNative(72 + 136, 76, 304, 144) == true and choice.index == 2,
  "centred NO row selects NO")

-- DYNAMIC layout moves an anchored ChoiceBox near the window bottom. Reverse
-- that placement before hit-testing, otherwise clicks appear vertically
-- offset from YES/NO.
runtime.viewport = {
  width = 1920, height = 1080,
  gameX = 640, gameY = 252,
  gameWidth = 640, gameHeight = 576,
  scale = 4, dpiX = 1, dpiY = 1,
}
game.renderer = {
  uiCentered = false,
  uiAnchorHold = false,
  uiScale = function() return 4 end,
  uiSize = function() return 160, 144 end,
}
choice.anchor = "bottom"
choice.index = 2
local anchoredX = 1168
local anchoredYesY = 744
local anchoredNoY = 808
check(native.hover(anchoredX, anchoredYesY) == true and choice.index == 1,
  "anchored visual YES maps to the YES row")
check(native.hover(anchoredX, anchoredNoY) == true and choice.index == 2,
  "anchored visual NO maps to the NO row")

print("Battle pointer smoke passed")
