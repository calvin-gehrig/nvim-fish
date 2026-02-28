-- nvim-fish/fish.lua — Fish sprites and spawner registration

local swim = require("nvim-fish.swim")
local engine = require("nvim-fish.engine")

local M = {}

-- ><> points RIGHT — used when swimming left-to-right
-- <>< points LEFT  — used when swimming right-to-left
local sprites = {
  right = "><>",
  left = "<><",
}

function M.register(opts)
  local spawner = swim.create_spawner({
    max_fish = opts.max_fish,
    spawn_chance = opts.spawn_chance,
    hl_group = opts.hl_group,
    sprites = sprites,
  }, engine)

  engine.register_spawner(spawner)
end

return M
