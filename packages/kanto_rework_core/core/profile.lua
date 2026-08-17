return function(options)
  local fs = assert(love and love.filesystem, "profile persistence needs love.filesystem")
  local path = assert(options and options.path, "profile path is required")
  local defaults = assert(options.defaults, "profile defaults are required")

  local function copy(source)
    local out = {}
    for key, value in pairs(source or {}) do out[key] = value end
    return out
  end

  local function sanitize(data)
    local out = copy(defaults)
    if type(data) ~= "table" then return out end
    if type(data.theme) == "string" then out.theme = data.theme end
    if type(data.overlayVisible) == "boolean" then
      out.overlayVisible = data.overlayVisible
    end
    if type(data.widgetLocked) == "boolean" then
      out.widgetLocked = data.widgetLocked
    end
    if type(data.widgetX) == "number" then
      out.widgetX = math.max(0, math.min(1, data.widgetX))
    end
    if type(data.widgetY) == "number" then
      out.widgetY = math.max(0, math.min(1, data.widgetY))
    end
    return out
  end

  local function loadProfile()
    if not fs.getInfo(path) then return copy(defaults) end
    local chunk, loadError = fs.load(path)
    if not chunk then return copy(defaults), loadError end
    local ok, data = pcall(chunk)
    if not ok then return copy(defaults), data end
    return sanitize(data)
  end

  local function serialize(profile)
    return table.concat({
      "return {",
      ("  theme = %q,"):format(profile.theme or defaults.theme),
      ("  overlayVisible = %s,"):format(tostring(profile.overlayVisible == true)),
      ("  widgetLocked = %s,"):format(tostring(profile.widgetLocked == true)),
      ("  widgetX = %.6f,"):format(tonumber(profile.widgetX) or defaults.widgetX),
      ("  widgetY = %.6f,"):format(tonumber(profile.widgetY) or defaults.widgetY),
      "}",
      "",
    }, "\n")
  end

  local function saveProfile(profile)
    local directory = path:match("^(.*)/[^/]+$")
    if directory and directory ~= "" then fs.createDirectory(directory) end
    return fs.write(path, serialize(sanitize(profile)))
  end

  return {
    load = loadProfile,
    save = saveProfile,
    sanitize = sanitize,
  }
end
