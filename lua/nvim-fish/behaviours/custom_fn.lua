-- nvim-fish/behaviours/custom_fn.lua — Wraps a user function into a behaviour

local M = {}

local CustomFn = {}
CustomFn.__index = CustomFn

function CustomFn:advance(swimmer, ctx)
  local dx, dy = self.fn(ctx.tick, swimmer, ctx)
  swimmer.col = swimmer.col + (dx or 0)
  swimmer.row = swimmer.row + (dy or 0)
end

function M.new(fn)
  return setmetatable({ fn = fn }, CustomFn)
end

return M
