-- nvim-fish/behaviours/sine.lua — Sine wave motion

local M = {}

local Sine = {}
Sine.__index = Sine

function Sine:advance(swimmer, ctx)
  swimmer.col = swimmer.col + swimmer.speed * swimmer.dir

  -- Sine wave applied to row based on age
  local base_row = swimmer._data.base_row
  if not base_row then
    base_row = swimmer.row
    swimmer._data.base_row = base_row
  end

  swimmer.row = base_row + self.amplitude * math.sin(swimmer.age / self.period * 2 * math.pi)
end

function M.new(opts)
  opts = opts or {}
  return setmetatable({
    amplitude = opts.amplitude or 2,
    period = opts.period or 20,
  }, Sine)
end

return M
