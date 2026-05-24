-- nvim-fish/behaviours/horizontal.lua — V0-compatible straight horizontal movement

local M = {}

local Horizontal = {}
Horizontal.__index = Horizontal

function Horizontal:advance(swimmer, ctx)
  swimmer.col = swimmer.col + swimmer.speed * swimmer.dir
end

function M.new(opts)
  return setmetatable({}, Horizontal)
end

return M
