local Presentation = {}
Presentation.__index = Presentation

-- World-only optical pass for the 3DWorld renderer.
-- This is intentionally a restrained screen-space approximation rather than
-- claiming to be true depth-buffer DOF: the public pipeline currently hands
-- worldPresent the finished world Canvas, not a semantic depth texture.
local SHADER = [[
extern vec2 texel_size;
extern number blur_px;
extern number focus_y;
extern number focus_band;
extern number haze_strength;
extern number vignette_strength;
extern number saturation;
extern number contrast;

vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc)
{
    float distance_from_focus = abs(tc.y - focus_y);
    float defocus = smoothstep(focus_band, focus_band + 0.24,
                               distance_from_focus);
    vec2 o = texel_size * blur_px * defocus;

    vec4 c = Texel(texture, tc) * 0.24;
    c += Texel(texture, tc + vec2( o.x, 0.0)) * 0.11;
    c += Texel(texture, tc + vec2(-o.x, 0.0)) * 0.11;
    c += Texel(texture, tc + vec2(0.0,  o.y)) * 0.11;
    c += Texel(texture, tc + vec2(0.0, -o.y)) * 0.11;
    c += Texel(texture, tc + vec2( o.x,  o.y)) * 0.08;
    c += Texel(texture, tc + vec2(-o.x,  o.y)) * 0.08;
    c += Texel(texture, tc + vec2( o.x, -o.y)) * 0.08;
    c += Texel(texture, tc + vec2(-o.x, -o.y)) * 0.08;

    float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    c.rgb = mix(vec3(luma), c.rgb, saturation);
    c.rgb = (c.rgb - vec3(0.5)) * contrast + vec3(0.5);

    -- Atmospheric separation is strongest toward the far/top part of the
    -- oblique composition.  It never touches the UI because this shader runs
    -- through worldPresent, before menus/dialogue are composited.
    float far_edge = max(0.08, focus_y - focus_band);
    float far_haze = 1.0 - smoothstep(0.0, far_edge, tc.y);
    vec3 haze = vec3(0.67, 0.75, 0.77);
    c.rgb = mix(c.rgb, haze, haze_strength * far_haze);

    vec2 centered = (tc - vec2(0.5)) * vec2(1.0, 0.78);
    float edge = smoothstep(0.36, 0.72, length(centered));
    c.rgb *= 1.0 - edge * vignette_strength;

    return c * color;
}
]]

local PRESETS = {
  [1] = {
    blurPx = 0.85,
    focusY = 0.56,
    focusBand = 0.16,
    haze = 0.035,
    vignette = 0.025,
    saturation = 1.035,
    contrast = 1.025,
  },
  [2] = {
    blurPx = 1.45,
    focusY = 0.57,
    focusBand = 0.13,
    haze = 0.060,
    vignette = 0.040,
    saturation = 1.045,
    contrast = 1.035,
  },
  [3] = {
    blurPx = 2.20,
    focusY = 0.59,
    focusBand = 0.11,
    haze = 0.085,
    vignette = 0.060,
    saturation = 1.055,
    contrast = 1.045,
  },
}

local function release(value)
  if value and type(value.release) == "function" then
    pcall(value.release, value)
  end
end

function Presentation.new()
  return setmetatable({
    shader = nil,
    canvas = nil,
    canvasW = 0,
    canvasH = 0,
    level = 0,
    disabled = false,
    lastError = nil,
  }, Presentation)
end

function Presentation:available()
  return not self.disabled
    and love and love.graphics
    and type(love.graphics.newCanvas) == "function"
    and type(love.graphics.newShader) == "function"
    and type(love.graphics.draw) == "function"
end

function Presentation:update(_, level)
  self.level = math.max(0, math.min(3, math.floor(tonumber(level) or 0)))
end

function Presentation:ensureResources(w, h)
  if not self:available() then return false end

  if not self.shader then
    local ok, shader = pcall(love.graphics.newShader, SHADER)
    if not ok or not shader then
      self.disabled = true
      self.lastError = tostring(shader or "shader compilation failed")
      return false
    end
    self.shader = shader
  end

  w, h = math.max(1, math.floor(w)), math.max(1, math.floor(h))
  if self.canvas and self.canvasW == w and self.canvasH == h then
    return true
  end

  release(self.canvas)
  local ok, canvas = pcall(love.graphics.newCanvas, w, h)
  if not ok or not canvas then
    self.lastError = tostring(canvas or "worldPresent canvas allocation failed")
    self.canvas = nil
    self.canvasW, self.canvasH = 0, 0
    return false
  end
  self.canvas = canvas
  self.canvasW, self.canvasH = w, h
  if self.canvas.setFilter then self.canvas:setFilter("nearest", "nearest") end
  return true
end

function Presentation:worldPresent(input, ctx, level)
  level = math.max(0, math.min(3, math.floor(tonumber(level) or self.level or 0)))
  if level <= 0 or not input then return input end

  local w = type(input.getWidth) == "function" and input:getWidth()
    or (ctx and ctx.width)
  local h = type(input.getHeight) == "function" and input:getHeight()
    or (ctx and ctx.height)
  if not (w and h and self:ensureResources(w, h)) then return input end

  local preset = PRESETS[level] or PRESETS[1]
  local ok, err
  love.graphics.push("all")
  ok, err = pcall(function()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(self.shader)
    self.shader:send("texel_size", { 1 / w, 1 / h })
    self.shader:send("blur_px", preset.blurPx)
    self.shader:send("focus_y", preset.focusY)
    self.shader:send("focus_band", preset.focusBand)
    self.shader:send("haze_strength", preset.haze)
    self.shader:send("vignette_strength", preset.vignette)
    self.shader:send("saturation", preset.saturation)
    self.shader:send("contrast", preset.contrast)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(input, 0, 0)
  end)
  love.graphics.pop()

  if not ok then
    self.lastError = tostring(err)
    return input
  end
  self.lastError = nil
  return self.canvas
end

function Presentation:invalidate()
  release(self.canvas)
  release(self.shader)
  self.canvas = nil
  self.shader = nil
  self.canvasW, self.canvasH = 0, 0
  self.disabled = false
  self.lastError = nil
end

return Presentation
