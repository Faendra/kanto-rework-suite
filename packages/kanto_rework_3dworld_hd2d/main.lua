local mod = ...

local WorldAdapter = require("sol3d.WorldAdapter")
local Renderer = require("sol3d.Renderer")

local adapter = WorldAdapter.new(mod)
local renderer = Renderer.new(adapter)

mod.exports.renderer = renderer
mod.exports.adapter = adapter

mod.content.render_pipelines:register("krs_3dworld", {
  label = "KRS 3DWORLD",
  levels = { "OFF", "HD2D", "DEPTH", "CINE" },
  hotkey = "6",
  priority = 60,
  available = function()
    return renderer:available()
  end,
  update = function(dt, level)
    renderer:update(dt, level)
  end,
  drawWorld = function(ctx)
    return renderer:drawWorld(ctx)
  end,
})
