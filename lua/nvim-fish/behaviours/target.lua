-- nvim-fish/behaviours/target.lua — Seek a word by pattern, then hand off

local behaviours -- lazy-loaded to avoid circular require

local M = {}

local Target = {}
Target.__index = Target

function Target:advance(swimmer, ctx)
  -- On first tick, find a target position
  if not swimmer._data.target_col then
    local target = self:_find_target(swimmer, ctx)
    if target then
      swimmer._data.target_col = target.col
      swimmer._data.target_row = target.row
    else
      -- No target found — hand off immediately
      self:_hand_off(swimmer)
      return
    end
  end

  -- Already handed off (shouldn't happen, but guard)
  if swimmer._data.target_col == false then
    swimmer.col = swimmer.col + swimmer.speed * swimmer.dir
    return
  end

  -- Steer toward target
  local dx = swimmer._data.target_col - swimmer.col
  local dy = swimmer._data.target_row - swimmer.row

  -- Horizontal movement toward target
  if math.abs(dx) > swimmer.speed then
    swimmer.col = swimmer.col + swimmer.speed * (dx > 0 and 1 or -1)
  else
    swimmer.col = swimmer._data.target_col
  end

  -- Vertical drift toward target row
  if math.abs(dy) > 0.5 then
    swimmer.row = swimmer.row + (dy > 0 and 0.5 or -0.5)
  end

  -- Reached target — hand off to then_behaviour
  if math.abs(dx) <= swimmer.speed and math.abs(dy) <= 0.5 then
    self:_hand_off(swimmer)
  end
end

function Target:_hand_off(swimmer)
  if not behaviours then
    behaviours = require("nvim-fish.behaviours")
  end
  swimmer.behaviour = behaviours.resolve(self.then_behaviour)
end

function Target:_find_target(swimmer, ctx)
  for row = 0, ctx.win_height - 1 do
    local text = ctx.get_visible_text(row)
    for _, pat in ipairs(self.patterns) do
      local s = text:find(pat)
      if s then
        return { row = row, col = s - 1 }
      end
    end
  end
  return nil
end

function M.new(opts)
  opts = opts or {}
  local patterns = {}
  if opts.pattern then
    table.insert(patterns, opts.pattern)
  end
  if opts.words then
    for _, w in ipairs(opts.words) do
      table.insert(patterns, vim.pesc(w))
    end
  end
  if #patterns == 0 then
    patterns = { "TODO" }
  end
  return setmetatable({
    patterns = patterns,
    then_behaviour = opts.then_behaviour or "horizontal",
  }, Target)
end

return M
