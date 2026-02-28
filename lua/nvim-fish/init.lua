-- nvim-fish/init.lua — Plugin setup, commands, config

local M = {}

local defaults = {
  auto_start = true,
  tick_ms = 150,
  max_fish = 5,
  spawn_chance = 0.1,
  hl_group = "NvimFish",
}

M._config = nil

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})
  M._config = opts

  local engine = require("nvim-fish.engine")
  local fish = require("nvim-fish.fish")

  fish.register({
    max_fish = opts.max_fish,
    spawn_chance = opts.spawn_chance,
    hl_group = opts.hl_group,
  })

  vim.api.nvim_create_user_command("FishStart", function()
    engine.start({ tick_ms = opts.tick_ms })
  end, { desc = "Start fish animation" })

  vim.api.nvim_create_user_command("FishStop", function()
    engine.stop()
  end, { desc = "Stop fish animation" })

  vim.api.nvim_create_user_command("FishToggle", function()
    engine.toggle({ tick_ms = opts.tick_ms })
  end, { desc = "Toggle fish animation" })

  if opts.auto_start then
    engine.start({ tick_ms = opts.tick_ms })
  end
end

return M
