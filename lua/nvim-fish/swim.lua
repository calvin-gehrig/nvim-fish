-- nvim-fish/swim.lua — Swimmer entity and spawner logic

local Swimmer = {}
Swimmer.__index = Swimmer

--- Create a new swimmer.
--- @param opts table { row, col, dir, speed, sprite, hl_group }
---   dir:  1 = swimming rightward (><>), -1 = swimming leftward (<><)
---   speed: columns per tick (positive float)
function Swimmer.new(opts)
  return setmetatable({
    row = opts.row,
    col = opts.col,
    dir = opts.dir,
    speed = opts.speed,
    sprite = opts.sprite,
    hl_group = opts.hl_group,
  }, Swimmer)
end

--- Advance position. Returns true to keep alive, false to remove.
function Swimmer:update(win_width, win_height)
  self.col = self.col + self.speed * self.dir

  -- Off-screen check: remove if fully past either edge
  if self.dir == 1 and self.col > win_width + 1 then
    return false
  end
  if self.dir == -1 and self.col < -(#self.sprite + 1) then
    return false
  end

  return true
end

--- Return render info for the engine.
function Swimmer:render()
  local col = math.floor(self.col)
  return {
    row = self.row,
    col = col,
    sprite = self.sprite,
    hl = self.hl_group,
  }
end

local M = {}

--- Create a spawner function for fish.
--- @param opts table { max_fish, spawn_chance, hl_group, sprites }
---   sprites: { right = "...", left = "..." }
function M.create_spawner(opts, engine)
  local sprites = opts.sprites
  local max_fish = opts.max_fish
  local spawn_chance = opts.spawn_chance
  local hl_group = opts.hl_group

  return function(win_info)
    -- Respect max_fish
    if engine.entity_count() >= max_fish then
      return nil
    end

    -- Random chance to spawn
    if math.random() > spawn_chance then
      return nil
    end

    local win_height = win_info.bot - win_info.top + 1
    local win_width = win_info.width

    -- Pick random edge
    local dir, start_col, sprite
    if math.random() < 0.5 then
      -- Enter from left, swim right
      dir = 1
      sprite = sprites.right
      start_col = -#sprite
    else
      -- Enter from right, swim left
      dir = -1
      sprite = sprites.left
      start_col = win_width
    end

    local row = math.random(0, math.max(0, win_height - 1))
    local speed = 0.5 + math.random() * 1.5 -- 0.5 to 2.0 columns per tick

    return Swimmer.new({
      row = row,
      col = start_col,
      dir = dir,
      speed = speed,
      sprite = sprite,
      hl_group = hl_group,
    })
  end
end

M.Swimmer = Swimmer

return M
