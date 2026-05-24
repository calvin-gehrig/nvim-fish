-- nvim-fish/swim.lua — Swimmer entity and spawner logic

local behaviours = require("nvim-fish.behaviours")

--- Compute the width of the widest line and the number of lines in a sprite.
local function sprite_dimensions(sprite)
  local lines = vim.split(sprite, "\n", { plain = true })
  local max_w = 0
  for _, line in ipairs(lines) do
    if #line > max_w then
      max_w = #line
    end
  end
  return max_w, #lines
end

local Swimmer = {}
Swimmer.__index = Swimmer

--- Create a new swimmer.
--- @param opts table { row, col, dir, speed, sprite, hl_group, behaviour }
---   dir:  1 = swimming rightward (><>), -1 = swimming leftward (<><)
---   speed: columns per tick (positive float)
---   behaviour: resolved behaviour table with :advance()
function Swimmer.new(opts)
  local sw, sh = sprite_dimensions(opts.sprite)
  return setmetatable({
    row = opts.row,
    col = opts.col,
    dir = opts.dir,
    speed = opts.speed,
    sprite = opts.sprite,
    sprite_width = sw,
    sprite_height = sh,
    hl_group = opts.hl_group,
    behaviour = opts.behaviour,
    age = 0,
    _data = {},
  }, Swimmer)
end

--- Advance position via behaviour. Returns true to keep alive, false to remove.
function Swimmer:update(ctx)
  self.age = self.age + 1

  self.behaviour:advance(self, ctx)

  -- Custom is_done or default off-screen check
  if self.behaviour.is_done then
    return not self.behaviour:is_done(self, ctx)
  end

  -- Default: remove if fully past either edge
  if self.dir == 1 and self.col > ctx.win_width + 1 then
    return false
  end
  if self.dir == -1 and self.col < -(self.sprite_width + 1) then
    return false
  end

  return true
end

--- Return render info for the engine.
function Swimmer:render()
  local col = math.floor(self.col)
  local row = math.floor(self.row)
  return {
    row = row,
    col = col,
    sprite = self.sprite,
    hl = self.hl_group,
  }
end

local M = {}

--- Create a spawner function for fish.
--- @param opts table { max_fish, spawn_chance, hl_group, sprites, behaviour }
---   sprites: { right = "...", left = "..." }
---   behaviour: spec passed to behaviours.resolve() per spawn
function M.create_spawner(opts, engine)
  local sprites = opts.sprites
  local max_fish = opts.max_fish
  local spawn_chance = opts.spawn_chance
  local hl_group = opts.hl_group
  local behaviour_spec = opts.behaviour

  return function(ctx)
    -- Respect max_fish
    if engine.entity_count() >= max_fish then
      return nil
    end

    -- Random chance to spawn
    if math.random() > spawn_chance then
      return nil
    end

    local win_height = ctx.win_height
    local win_width = ctx.win_width

    -- Pick random edge
    local dir, start_col, sprite
    if math.random() < 0.5 then
      -- Enter from left, swim right
      dir = 1
      sprite = sprites.right
      local sw = sprite_dimensions(sprite)
      start_col = -sw
    else
      -- Enter from right, swim left
      dir = -1
      sprite = sprites.left
      start_col = win_width
    end

    -- Account for sprite height so bottom lines don't spawn below viewport
    local _, sh = sprite_dimensions(sprite)
    local max_row = math.max(0, win_height - sh)
    local row = math.random(0, max_row)
    local speed = 0.5 + math.random() * 1.5 -- 0.5 to 2.0 columns per tick

    return Swimmer.new({
      row = row,
      col = start_col,
      dir = dir,
      speed = speed,
      sprite = sprite,
      hl_group = hl_group,
      behaviour = behaviours.resolve(behaviour_spec),
    })
  end
end

M.Swimmer = Swimmer

return M
