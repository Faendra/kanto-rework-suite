local Theme = {}

Theme.palettes = {
  field_journal = {
    id = "field_journal",
    name = "Field Journal",
    backdrop = { 0.025, 0.026, 0.030, 0.28 },
    paper = { 0.945, 0.912, 0.835, 0.985 },
    paperRaised = { 0.992, 0.972, 0.920, 1.000 },
    ink = { 0.080, 0.075, 0.068, 1.000 },
    muted = { 0.330, 0.300, 0.270, 1.000 },
    subtle = { 0.530, 0.480, 0.410, 0.800 },
    accent = { 0.760, 0.105, 0.095, 1.000 },
    accentDark = { 0.380, 0.055, 0.050, 1.000 },
    accentSoft = { 0.760, 0.105, 0.095, 0.150 },
    onAccent = { 1.000, 0.975, 0.930, 1.000 },
    border = { 0.210, 0.185, 0.155, 0.880 },
    divider = { 0.300, 0.260, 0.220, 0.320 },
    shadow = { 0.000, 0.000, 0.000, 0.360 },
    night = { 0.050, 0.055, 0.070, 0.975 },
    nightRaised = { 0.085, 0.090, 0.110, 1.000 },
    nightText = { 0.970, 0.955, 0.920, 1.000 },
    nightMuted = { 0.720, 0.690, 0.630, 1.000 },
  },
  graphite = {
    id = "graphite",
    name = "Graphite",
    backdrop = { 0.000, 0.000, 0.000, 0.20 },
    paper = { 0.055, 0.060, 0.072, 0.985 },
    paperRaised = { 0.085, 0.092, 0.112, 1.000 },
    ink = { 0.965, 0.958, 0.930, 1.000 },
    muted = { 0.690, 0.685, 0.660, 1.000 },
    subtle = { 0.500, 0.505, 0.540, 0.850 },
    accent = { 0.925, 0.260, 0.210, 1.000 },
    accentDark = { 0.480, 0.110, 0.090, 1.000 },
    accentSoft = { 0.925, 0.260, 0.210, 0.180 },
    onAccent = { 1.000, 0.980, 0.950, 1.000 },
    border = { 0.380, 0.390, 0.430, 0.900 },
    divider = { 0.500, 0.510, 0.550, 0.300 },
    shadow = { 0.000, 0.000, 0.000, 0.480 },
    night = { 0.030, 0.034, 0.044, 0.985 },
    nightRaised = { 0.075, 0.082, 0.102, 1.000 },
    nightText = { 0.970, 0.965, 0.940, 1.000 },
    nightMuted = { 0.720, 0.715, 0.690, 1.000 },
  },
}

function Theme.get(id)
  return Theme.palettes[id] or Theme.palettes.field_journal
end

function Theme.setColor(color, alpha)
  if not color then
    love.graphics.setColor(1, 1, 1, alpha or 1)
    return
  end
  love.graphics.setColor(color[1], color[2], color[3],
    alpha ~= nil and alpha or color[4] or 1)
end

return Theme
