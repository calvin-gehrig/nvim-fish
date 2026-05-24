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
  auto_start = true,       -- start swimming on setup
  tick_ms = 150,           -- animation speed (ms per frame)
  max_fish = 5,            -- maximum fish on screen
  spawn_chance = 0.1,      -- probability of spawning a fish each tick
  hl_group = "NvimFish",   -- highlight group (defaults to Comment)
  behaviour = "wander",    -- movement behaviour (see Behaviours below)
})
```

## Behaviours

Control how fish move. The default `"wander"` adds subtle vertical jitter on top of horizontal swimming.

### Built-in presets

| Name | Description |
|---|---|
| `"horizontal"` | Straight horizontal line (V0 behaviour) |
| `"wander"` | Horizontal + random vertical jitter (default) |
| `"sine"` | Smooth sine wave motion |
| `"zigzag"` | Triangle wave (sharp zigzag) |
| `"target"` | Swim toward a word matching a pattern |

### Using presets

```lua
-- String shorthand
require("nvim-fish").setup({ behaviour = "sine" })

-- With options
require("nvim-fish").setup({
  behaviour = { "sine", amplitude = 3, period = 20 },
})

-- Target a pattern
require("nvim-fish").setup({
  behaviour = { "target", pattern = "TODO" },
})
```

### Preset options

**sine** / **zigzag**: `amplitude` (default 2), `period` (default 20)

**wander**: `jitter_chance` (default 0.08 — probability of vertical movement per tick)

**target**: `pattern` (Lua pattern string), `words` (list of literal strings)

### Custom function

Pass a function that returns `dx, dy` per tick:

```lua
require("nvim-fish").setup({
  behaviour = function(tick, swimmer, ctx)
    return swimmer.speed * swimmer.dir, 0.3 * math.sin(tick / 10)
  end,
})
```

### Raw behaviour table

Pass a table with an `advance` method directly:

```lua
require("nvim-fish").setup({
  behaviour = {
    advance = function(self, swimmer, ctx)
      swimmer.col = swimmer.col + swimmer.speed * swimmer.dir
    end,
  },
})
```

## Multi-species

Run multiple species simultaneously with independent behaviours, sprites, and limits:

```lua
require("nvim-fish").setup({
  species = {
    fish = { max = 3, behaviour = "wander" },
    whale = {
      max = 1,
      behaviour = { "sine", amplitude = 1 },
      sprites = { right = ">===>", left = "<===<" },
    },
  },
})
```

Each species entry accepts: `max`, `spawn_chance`, `hl_group`, `behaviour`, `sprites`.
Top-level defaults are used for any omitted field.

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
- **behaviours/** — pluggable movement strategies

See [GUIDE.md](GUIDE.md) for a full guide on creating new species and behaviours.
