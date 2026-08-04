local Theme = {}

Theme.palettes = {
  field_journal = {
    id = "field_journal",
    paper = { 0.93, 0.89, 0.78, 0.98 },
    paperRaised = { 0.98, 0.95, 0.86, 1.00 },
    ink = { 0.08, 0.075, 0.065, 1.00 },
    muted = { 0.31, 0.29, 0.25, 1.00 },
    accent = { 0.71, 0.075, 0.08, 1.00 },
    accentSoft = { 0.82, 0.20, 0.16, 0.18 },
    border = { 0.19, 0.17, 0.14, 0.72 },
    shadow = { 0.02, 0.02, 0.02, 0.28 },
  },
  graphite = {
    id = "graphite",
    paper = { 0.055, 0.060, 0.070, 0.98 },
    paperRaised = { 0.090, 0.095, 0.110, 1.00 },
    ink = { 0.96, 0.95, 0.91, 1.00 },
    muted = { 0.69, 0.68, 0.64, 1.00 },
    accent = { 0.86, 0.20, 0.16, 1.00 },
    accentSoft = { 0.86, 0.20, 0.16, 0.20 },
    border = { 0.37, 0.37, 0.38, 0.70 },
    shadow = { 0.00, 0.00, 0.00, 0.42 },
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
  love.graphics.setColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

return Theme
