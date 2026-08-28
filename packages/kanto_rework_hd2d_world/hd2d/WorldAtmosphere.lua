local WorldAtmosphere = {}
WorldAtmosphere.__index = WorldAtmosphere

local SHADER_SOURCE = [[
extern vec2 texelSize;
extern number focusY;
extern number focusWidth;
extern number blurStrength;
extern number hazeStrength;
extern number vignetteStrength;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen)
{
    vec4 base = Texel(tex, uv);

    float focusDistance = abs(uv.y - focusY);
    float blurMask = smoothstep(focusWidth, focusWidth + 0.28, focusDistance)
                   * blurStrength;

    vec2 spread = texelSize * (1.0 + blurMask * 2.4);
    vec4 soft = base * 0.42;
    soft += Texel(tex, uv + vec2(spread.x, 0.0)) * 0.145;
    soft += Texel(tex, uv - vec2(spread.x, 0.0)) * 0.145;
    soft += Texel(tex, uv + vec2(0.0, spread.y)) * 0.145;
    soft += Texel(tex, uv - vec2(0.0, spread.y)) * 0.145;
    vec4 outColor = mix(base, soft, blurMask);

    // Atmospheric separation is strongest behind the player and deliberately
    // restrained around the focus plane. This keeps gameplay sprites crisp
    // while DEPTH/CINEMA visibly separate distant world planes.
    float hazeEnd = max(0.001, focusY - focusWidth);
    float farMask = 1.0 - smoothstep(0.0, hazeEnd, uv.y);
    vec3 hazeTint = vec3(0.86, 0.91, 0.94);
    outColor.rgb = mix(outColor.rgb, hazeTint,
                       farMask * hazeStrength * 0.30);

    // World-only vignette; dialog boxes and menus are composited after this.
    vec2 centered = uv - vec2(0.5, 0.52);
    float vignette = smoothstep(0.28, 0.72, dot(centered, centered) * 1.45);
    outColor.rgb *= 1.0 - vignette * vignetteStrength;

    return outColor * color;
}
]]

-- The three user-facing levels should be visibly distinct, not three nearly
-- identical switches. HD2D remains almost pixel-sharp; DEPTH adds a moderate
-- focal plane; CINEMA intentionally pushes the Octopath-like miniature lens.
local PRESETS = {
  [1] = { focusY = 0.57, focusWidth = 0.30, blur = 0.045, haze = 0.040, vignette = 0.018 },
  [2] = { focusY = 0.57, focusWidth = 0.23, blur = 0.280, haze = 0.110, vignette = 0.035 },
  [3] = { focusY = 0.57, focusWidth = 0.19, blur = 0.480, haze = 0.160, vignette = 0.055 },
}

local function release(obj)
  if obj and obj.release then pcall(obj.release, obj) end
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function WorldAtmosphere.new()
  return setmetatable({
    shader = nil,
    target = nil,
    targetW = 0,
    targetH = 0,
    shaderFailed = false,
    lastPasses = 0,
    lastBypassed = false,
    lastLevel = 0,
    lastFocusY = nil,
    lastBlurStrength = 0,
    lastHazeStrength = 0,
  }, WorldAtmosphere)
end

function WorldAtmosphere:invalidate()
  release(self.target)
  self.target = nil
  self.targetW, self.targetH = 0, 0
  self.lastPasses = 0
  self.lastBypassed = false
  self.lastFocusY = nil
  self.lastBlurStrength = 0
  self.lastHazeStrength = 0
end

function WorldAtmosphere:shaderAvailable()
  return love ~= nil
     and love.graphics ~= nil
     and type(love.graphics.newShader) == "function"
end

function WorldAtmosphere:ensureShader()
  if self.shader then return self.shader end
  if self.shaderFailed or not self:shaderAvailable() then return nil end
  local ok, shader = pcall(love.graphics.newShader, SHADER_SOURCE)
  if not ok or not shader then
    self.shaderFailed = true
    return nil
  end
  self.shader = shader
  return shader
end

function WorldAtmosphere:ensureTarget(canvas)
  if not (canvas and love and love.graphics and love.graphics.newCanvas) then
    return nil
  end
  local w = canvas.getWidth and canvas:getWidth() or 0
  local h = canvas.getHeight and canvas:getHeight() or 0
  if w <= 0 or h <= 0 then return nil end
  if not self.target or self.targetW ~= w or self.targetH ~= h then
    release(self.target)
    self.target = love.graphics.newCanvas(w, h)
    if self.target.setFilter then self.target:setFilter("nearest", "nearest") end
    self.targetW, self.targetH = w, h
  end
  return self.target
end

function WorldAtmosphere:present(canvas, ctx, level, requestedFocusY)
  self.lastLevel = tonumber(level) or 0
  self.lastPasses = 0
  self.lastBypassed = false
  self.lastFocusY = nil
  self.lastBlurStrength = 0
  self.lastHazeStrength = 0
  if not canvas or self.lastLevel <= 0 then
    self.lastBypassed = true
    return canvas
  end

  local shader = self:ensureShader()
  local target = shader and self:ensureTarget(canvas) or nil
  if not (shader and target) then
    self.lastBypassed = true
    return canvas
  end

  local preset = PRESETS[math.max(1, math.min(3, self.lastLevel))] or PRESETS[1]
  local focus = tonumber(requestedFocusY)
  if not focus or focus ~= focus then focus = preset.focusY end
  focus = clamp(focus, 0.18, 0.82)
  self.lastFocusY = focus
  self.lastBlurStrength = preset.blur
  self.lastHazeStrength = preset.haze

  local w, h = self.targetW, self.targetH
  shader:send("texelSize", { 1 / w, 1 / h })
  shader:send("focusY", focus)
  shader:send("focusWidth", preset.focusWidth)
  shader:send("blurStrength", preset.blur)
  shader:send("hazeStrength", preset.haze)
  shader:send("vignetteStrength", preset.vignette)

  love.graphics.push("all")
  love.graphics.setCanvas(target)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setShader(shader)
  love.graphics.draw(canvas, 0, 0)
  love.graphics.setShader()
  love.graphics.setCanvas()
  love.graphics.pop()

  self.lastPasses = 1
  return target
end

return WorldAtmosphere