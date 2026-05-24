-- nvim-fish/behaviours/wander.lua — Horizontal + random vertical jitter

local M = {}

local Wander = {}
Wander.__index = Wander

function Wander:advance(swimmer, ctx)
  -- Horizontal movement
  swimmer.col = swimmer.col + swimmer.speed * swimmer.dir

  -- Random vertical jitter (8% chance per tick)
  if math.random() < self.jitter_chance then
    local dy = math.random() < 0.5 and -1 or 1
    local new_row = swimmer.row + dy
    if new_row >= 0 and new_row < ctx.win_height then
      swimmer.row = new_row
    end
  end
end

function M.new(opts)
  opts = opts or {}
  return setmetatable({
    jitter_chance = opts.jitter_chance or 0.08,
  }, Wander)
end

return M
