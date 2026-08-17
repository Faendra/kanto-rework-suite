local packageDir = assert(arg[1], "package directory argument required")

local function check(value, message)
  if not value then error("Manager wheel smoke: " .. tostring(message), 0) end
end

love = {
  filesystem = { load = function(path) return loadfile(path) end },
}

local taps = {}
local manager = {
  screenId = "ManagerState",
  screen = "list",
  cursor = 1,
  scroll = 1,
  backStack = {},
  rowsForScreen = function()
    return { { header = true }, { label = "MOD A" }, { label = "MOD B" } }
  end,
}
local game = {
  stack = {
    top = function() return manager end,
  },
}
local runtime = {
  game = game,
  viewport = {
    width = 1920, height = 1080,
    gameX = 600, gameY = 0, gameWidth = 1200, gameHeight = 1080,
  },
}
local mod = {
  input = {
    tap = function(_, currentGame, button)
      check(currentGame == game, "wheel input targets the live Game object")
      taps[#taps + 1] = button
    end,
  },
}
local presenter = {
  isSupportedStartMenu = function() return false end,
}

local chunk, loadError = loadfile(packageDir .. "/core/native_pointer.lua")
check(chunk, loadError)
local createNativePointer = chunk()
local native = createNativePointer({
  mod = mod,
  runtime = runtime,
  presenter = presenter,
})

check(native.kind() == "mod_manager", "ManagerState is detected explicitly")
check(native.wheel(-1) == true, "wheel down is consumed by ManagerState")
check(taps[#taps] == "down", "wheel down queues native Down")
check(native.wheel(1) == true, "wheel up is consumed by ManagerState")
check(taps[#taps] == "up", "wheel up queues native Up")

-- ManagerState routes the injected direction itself. The adapter therefore
-- stays valid across its list, detail, options, errors and modal screens.
manager.screen = "options"
manager.optionRows = { { id = "one" }, { id = "two" } }
check(native.wheel(-1) == true and taps[#taps] == "down",
  "per-mod options also receive native Down")
manager.overlay = { kind = "confirm", index = 1 }
check(native.wheel(1) == true and taps[#taps] == "up",
  "manager confirmation overlays receive native Up")

-- Do not turn every unknown state into wheel navigation.
game.stack.top = function() return { screenId = "UnknownState" } end
local before = #taps
check(native.wheel(-1) == false, "unknown state declines wheel handling")
check(#taps == before, "unknown state receives no injected direction")

print("Manager wheel smoke passed")
