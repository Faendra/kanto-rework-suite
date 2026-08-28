local WorldAtmosphere = {}
WorldAtmosphere.__index = WorldAtmosphere

local SHADER_SOURCE = [[
extern vec2 texelSize;
extern number focusY;
extern number focusWidth;
extern number blurStrength;
extern number hazeStrength;
extern number vignetteStrength;
extern number bloomStrength;
extern number gradeStrength;

float luminance(vec3 c)
{
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Bloom only a bright feature that is locally brighter than its immediate
// neighborhood. A broad pale road/roof therefore stays textured instead of
// glowing just because every pixel is high-luminance.
vec3 brightSample(Image tex, vec2 uv)
{
    vec3 c = Texel(tex, uv).rgb;
    float lum = luminance(c);
    float neighbors = 0.0;
    neighbors += luminance(Texel(tex, uv + vec2(texelSize.x, 0.0)).rgb);
    neighbors += luminance(Texel(tex, uv - vec2(texelSize.x, 0.0)).rgb);
    neighbors += luminance(Texel(tex, uv + vec2(0.0, texelSize.y)).rgb);
    neighbors += luminance(Texel(tex, uv - vec2(0.0, texelSize.y)).rgb);
    neighbors *= 0.25;
    float localPeak = max(0.0, lum - neighbors);
    float peakGate = smoothstep(0.020, 0.115, localPeak);
    float lightGate = smoothstep(0.58, 0.90, lum);
    return c * peakGate * lightGate;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen)
{
    vec4 base = Texel(tex, uv);

    // Tilt-shift / miniature focal plane. Gameplay near the player stays crisp;
    // foreground and distant world planes soften progressively.
    float focusDistance = abs(uv.y - focusY);
    float blurMask = smoothstep(focusWidth, focusWidth + 0.26, focusDistance)
                   * blurStrength;

    vec2 spread = texelSize * (1.2 + blurMask * 3.8);
    vec4 soft = base * 0.34;
    soft += Texel(tex, uv + vec2(spread.x, 0.0)) * 0.115;
    soft += Texel(tex, uv - vec2(spread.x, 0.0)) * 0.115;
    soft += Texel(tex, uv + vec2(0.0, spread.y)) * 0.115;
    soft += Texel(tex, uv - vec2(0.0, spread.y)) * 0.115;
    soft += Texel(tex, uv + spread) * 0.050;
    soft += Texel(tex, uv - spread) * 0.050;
    soft += Texel(tex, uv + vec2(spread.x, -spread.y)) * 0.050;
    soft += Texel(tex, uv + vec2(-spread.x, spread.y)) * 0.050;
    vec4 outColor = mix(base, soft, blurMask);

    // Narrow, contrast-gated world bloom. This creates pinprick highlights and
    // window sparkle without bleaching pale Gen I ground and roof materials.
    vec2 bloomStep = texelSize * 3.0;
    vec3 bloom = brightSample(tex, uv + vec2(bloomStep.x, 0.0));
    bloom += brightSample(tex, uv - vec2(bloomStep.x, 0.0));
    bloom += brightSample(tex, uv + vec2(0.0, bloomStep.y));
    bloom += brightSample(tex, uv - vec2(0.0, bloomStep.y));
    bloom += brightSample(tex, uv + bloomStep);
    bloom += brightSample(tex, uv - bloomStep);
    bloom += brightSample(tex, uv + vec2(bloomStep.x, -bloomStep.y));
    bloom += brightSample(tex, uv + vec2(-bloomStep.x, bloomStep.y));
    bloom *= 0.125;
    outColor.rgb += bloom * bloomStrength;

    // Atmospheric separation behind the player. This acts on the world canvas
    // only; menus and dialog boxes are composited by Gen1Recomp afterwards.
    float hazeEnd = max(0.001, focusY - focusWidth);
    float farMask = 1.0 - smoothstep(0.0, hazeEnd, uv.y);
    vec3 hazeTint = vec3(0.86, 0.91, 0.94);
    outColor.rgb = mix(outColor.rgb, hazeTint,
                       farMask * hazeStrength * 0.30);

    // Gentle cinematic grade: cooler shadows, warmer highlights and a weak
    // upper-left sun wash. This gives the diorama directional light without
    // recolouring the original Game Boy material identity.
    float lum = luminance(outColor.rgb);
    float hi = smoothstep(0.40, 0.90, lum);
    vec3 grade = mix(vec3(0.97, 1.00, 1.04),
                     vec3(1.05, 1.02, 0.96), hi);
    outColor.rgb *= mix(vec3(1.0), grade, gradeStrength);
    float sun = (1.0 - uv.x) * (1.0 - uv.y);
    outColor.rgb += vec3(1.00, 0.93, 0.79)
                    * sun * gradeStrength * 0.026;

    // Recover detail in near-white Game Boy palette regions. A soft shoulder
    // compresses only the very top of the range and nudges it toward warm
    // ivory; midtones and saturated grass/water are left intact.
    lum = luminance(outColor.rgb);
    float chalk = smoothstep(0.76, 1.00, lum);
    float shoulder = chalk * (0.050 + 0.055 * gradeStrength);
    outColor.rgb *= 1.0 - shoulder;
    outColor.rgb = mix(outColor.rgb,
                       outColor.rgb * vec3(1.00, 0.995, 0.965),
                       chalk * 0.16);

    // World-only vignette, deliberately light enough not to obscure border
    // scenery or route transitions.
    vec2 centered = uv - vec2(0.5, 0.52);
    float vignette = smoothstep(0.28, 0.72, dot(centered, centered) * 1.45);
    outColor.rgb *= 1.0 - vignette * vignetteStrength;

    return vec4(clamp(outColor.rgb, 0.0, 1.0), outColor.a) * color;
}
]]

-- HD2D remains crisp and restrained; DEPTH adds the miniature lens; CINEMA
-- pushes bloom/tilt-shift further for the strongest Octopath-like staging.
local PRESETS = {
  [1] = {
    focusY = 0.57, focusWidth = 0.30,
    blur = 0.050, haze = 0.030, vignette = 0.018,
    bloom = 0.040, grade = 0.080,
  },
  [2] = {
    focusY = 0.57, focusWidth = 0.22,
    blur = 0.300, haze = 0.095, vignette = 0.034,
    bloom = 0.105, grade = 0.170,
  },
  [3] = {
    focusY = 0.57, focusWidth = 0.18,
    blur = 0.490, haze = 0.145, vignette = 0.052,
    bloom = 0.165, grade = 0.240,
  },
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
    lastBloomStrength = 0,
    lastGradeStrength = 0,
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
  self.lastBloomStrength = 0
  self.lastGradeStrength = 0
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
  self.lastBloomStrength = 0
  self.lastGradeStrength = 0
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
  self.lastBloomStrength = preset.bloom
  self.lastGradeStrength = preset.grade

  local w, h = self.targetW, self.targetH
  shader:send("texelSize", { 1 / w, 1 / h })
  shader:send("focusY", focus)
  shader:send("focusWidth", preset.focusWidth)
  shader:send("blurStrength", preset.blur)
  shader:send("hazeStrength", preset.haze)
  shader:send("vignetteStrength", preset.vignette)
  shader:send("bloomStrength", preset.bloom)
  shader:send("gradeStrength", preset.grade)

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
