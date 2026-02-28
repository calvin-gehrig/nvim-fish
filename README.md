# nvim-fish

Animated ASCII fish swimming across your Neovim buffer.

```
                ><>
        <><
   ><>
```

Fish appear from screen edges, swim across, and pass behind real text.

## Installation

### lazy.nvim

```lua
{
  "caelim/nvim-fish",
  config = function()
    require("nvim-fish").setup()
  end,
}
```

### Local (from a directory)

```lua
{
  dir = "~/Repository/nvim-fish",
  lazy = false,
  config = function()
    require("nvim-fish").setup()
  end,
}
```

## Configuration

All options with their defaults:

```lua
require("nvim-fish").setup({
  auto_start = true,    -- start swimming on setup
  tick_ms = 150,        -- animation speed (ms per frame)
  max_fish = 5,         -- maximum fish on screen
  spawn_chance = 0.1,   -- probability of spawning a fish each tick
  hl_group = "NvimFish", -- highlight group (defaults to Comment)
})
```

## Commands

| Command       | Description              |
|---------------|--------------------------|
| `:FishStart`  | Start the animation      |
| `:FishStop`   | Stop the animation       |
| `:FishToggle` | Toggle the animation     |

## How It Works

Fish are rendered as extmarks with `virt_text_win_col` overlay positioning. When a fish overlaps real buffer text, those characters are clipped so the fish appears to swim behind the text.

The engine is layered so other animations could reuse it:

- **engine.lua** — timer, extmark rendering, text-clipping
- **swim.lua** — generic swimmer entity with position, direction, speed
- **fish.lua** — fish sprites (`><>` and `<><`)
