-- nvim-fish/behaviours/zigzag.lua — Triangle wave motion

local M = {}

local Zigzag = {}
Zigzag.__index = Zigzag

function Zigzag:advance(swimmer, ctx)
  swimmer.col = swimmer.col + swimmer.speed * swimmer.dir

  local base_row = swimmer._data.base_row
  if not base_row then
    base_row = swimmer.row
    swimmer._data.base_row = base_row
  end

  -- Triangle wave: linearly ramp up then down
  local phase = (swimmer.age % self.period) / self.period
  local wave
  if phase < 0.5 then
    wave = phase * 2
  else
    wave = (1 - phase) * 2
  end
  swimmer.row = base_row + self.amplitude * (2 * wave - 1)
end

function M.new(opts)
  opts = opts or {}
  return setmetatable({
    amplitude = opts.amplitude or 2,
    period = opts.period or 20,
  }, Zigzag)
end

return M
