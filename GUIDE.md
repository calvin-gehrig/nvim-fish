# Creating Species and Behaviours

This guide covers the nvim-fish architecture and how to extend it with new species and movement behaviours.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  init.lua  (config, commands, setup)            │
│    └─ fish.lua  (sprites, registers spawner)    │
│         └─ swim.lua  (Swimmer entity, spawner)  │
│              ├─ engine.lua  (timer, rendering)  │
│              └─ behaviours/  (movement logic)   │
└─────────────────────────────────────────────────┘
```

**engine.lua** runs a timer that each tick: builds a `ctx` object, calls spawners to create new entities, calls `entity:update(ctx)` to advance them, calls `entity:render()` to draw extmarks.

**swim.lua** defines the `Swimmer` entity (position, direction, speed, sprite) and a `create_spawner()` factory. The spawner picks a random edge, direction, row, and speed, then creates a Swimmer with a resolved behaviour.

**behaviours/** contains the movement strategies. Each behaviour is a table with an `advance(self, swimmer, ctx)` method that mutates `swimmer.col` and `swimmer.row`.

## The Swimmer Object

When your behaviour's `advance()` is called, the swimmer has these fields:

```lua
swimmer.col       -- float, current horizontal position (window column)
swimmer.row       -- float, current vertical position (window row, 0-indexed from viewport top)
swimmer.dir       -- 1 (rightward) or -1 (leftward)
swimmer.speed     -- float, columns per tick (always positive, 0.5–2.0)
swimmer.sprite    -- string, the ASCII art for this direction
swimmer.hl_group  -- string, highlight group name
swimmer.age       -- int, ticks since spawn (incremented before advance)
swimmer._data     -- table, private storage for your behaviour (empty on spawn)
```

Your behaviour mutates `col` and `row` directly. The engine floors both values when rendering, so you can use floats for smooth movement.

## The Context Object

Every tick, the engine builds a `ctx` passed to `advance()`, `is_done()`, and spawners:

```lua
ctx.win_width           -- int, window width in columns
ctx.win_height          -- int, visible window height in lines
ctx.win_info            -- table, raw { buf, win, top, bot, width }
ctx.entities            -- table, list of all alive entities this tick
ctx.tick                -- int, global tick counter (resets on stop)
ctx.get_visible_text(row)  -- function, returns the buffer text at visible row
```

## Writing a Behaviour

A behaviour is a Lua module that returns `{ new = function(opts) }`. The `new` function returns a table with:

- `advance(self, swimmer, ctx)` — **required**. Mutate `swimmer.col` and `swimmer.row`.
- `is_done(self, swimmer, ctx)` — *optional*. Return `true` to remove the swimmer. If absent, the engine removes the swimmer when it goes off-screen.

### Minimal example

`lua/nvim-fish/behaviours/drift.lua`:

```lua
local M = {}

local Drift = {}
Drift.__index = Drift

function Drift:advance(swimmer, ctx)
  -- Slow horizontal movement
  swimmer.col = swimmer.col + swimmer.speed * swimmer.dir * 0.5
  -- Constant gentle downward drift
  swimmer.row = swimmer.row + 0.1
end

function M.new(opts)
  return setmetatable({}, Drift)
end

return M
```

### With configurable options

`lua/nvim-fish/behaviours/bounce.lua`:

```lua
local M = {}

local Bounce = {}
Bounce.__index = Bounce

function Bounce:advance(swimmer, ctx)
  swimmer.col = swimmer.col + swimmer.speed * swimmer.dir

  -- Initialize vertical direction
  if not swimmer._data.vdir then
    swimmer._data.vdir = 1
    swimmer._data.base_row = swimmer.row
  end

  swimmer.row = swimmer.row + self.vy * swimmer._data.vdir

  -- Bounce off top/bottom edges
  if swimmer.row <= 0 then
    swimmer.row = 0
    swimmer._data.vdir = 1
  elseif swimmer.row >= ctx.win_height - 1 then
    swimmer.row = ctx.win_height - 1
    swimmer._data.vdir = -1
  end
end

function M.new(opts)
  opts = opts or {}
  return setmetatable({
    vy = opts.vy or 0.3,  -- vertical speed per tick
  }, Bounce)
end

return M
```

### With custom is_done

Use `is_done` when you want a swimmer to disappear based on custom logic instead of going off-screen:

```lua
function Expire:advance(swimmer, ctx)
  swimmer.col = swimmer.col + swimmer.speed * swimmer.dir
end

function Expire:is_done(swimmer, ctx)
  return swimmer.age > self.max_age  -- despawn after N ticks
end
```

When `is_done` is present, the engine skips its default off-screen check entirely. If you still want off-screen removal, include it in your `is_done` logic.

### Registering a preset

To make your behaviour available as a string preset (e.g. `behaviour = "bounce"`), add it to the `presets` table in `behaviours/init.lua`:

```lua
local presets = {
  horizontal = "nvim-fish.behaviours.horizontal",
  wander = "nvim-fish.behaviours.wander",
  sine = "nvim-fish.behaviours.sine",
  zigzag = "nvim-fish.behaviours.zigzag",
  target = "nvim-fish.behaviours.target",
  bounce = "nvim-fish.behaviours.bounce",  -- add this
}
```

Without registration, users can still use your behaviour by passing the raw table:

```lua
local bounce = require("nvim-fish.behaviours.bounce")
require("nvim-fish").setup({ behaviour = bounce.new({ vy = 0.5 }) })
```

## Creating a New Species

A species is just a combination of sprites + behaviour + spawn settings. You don't need any new files — use the `species` table in setup:

```lua
require("nvim-fish").setup({
  species = {
    fish = { max = 3 },
    jellyfish = {
      max = 2,
      spawn_chance = 0.05,
      sprites = { right = "~{^.^}~", left = "~{^.^}~" },
      behaviour = { "sine", amplitude = 1, period = 30 },
      hl_group = "NvimFish",
    },
  },
})
```

Each species registers its own independent spawner with the engine. They share the global tick and entity list but each has its own `max` count enforced against the total entity pool.

### Species with custom sprites

Sprites need a `right` and `left` variant. `right` is shown when `dir = 1` (swimming left-to-right), `left` when `dir = -1`.

```lua
sprites = {
  right = ">==>",   -- facing right, swims rightward
  left  = "<==<",   -- facing left, swims leftward
}
```

For symmetric creatures, both can be the same string:

```lua
sprites = { right = "-<(O)>-", left = "-<(O)>-" }
```

### Species with a dedicated file

For reusable species, create a module like `fish.lua`. Here's a complete example:

`lua/nvim-fish/crab.lua`:

```lua
local swim = require("nvim-fish.swim")
local engine = require("nvim-fish.engine")

local M = {}

local sprites = {
  right = "(V)(;,,;)(V)",
  left  = "(V)(;,,;)(V)",
}

function M.register(opts)
  local spawner = swim.create_spawner({
    max_fish = opts.max_fish or 2,
    spawn_chance = opts.spawn_chance or 0.03,
    hl_group = opts.hl_group or "NvimFish",
    sprites = opts.sprites or sprites,
    behaviour = opts.behaviour or "zigzag",
  }, engine)

  engine.register_spawner(spawner)
end

return M
```

Then call it from `init.lua`'s setup, or directly:

```lua
require("nvim-fish.crab").register({ max_fish = 1 })
```

## Using _data for State

`swimmer._data` is an empty table unique to each swimmer instance. Use it to store per-swimmer state that your behaviour needs across ticks:

```lua
function MyBehaviour:advance(swimmer, ctx)
  -- Initialize once
  if not swimmer._data.initialized then
    swimmer._data.initialized = true
    swimmer._data.base_row = swimmer.row
    swimmer._data.phase = math.random() * math.pi * 2
  end

  swimmer.col = swimmer.col + swimmer.speed * swimmer.dir
  swimmer.row = swimmer._data.base_row
    + 2 * math.sin(swimmer.age / 15 + swimmer._data.phase)
end
```

Don't store state on `self` (the behaviour table) — a single behaviour instance may be shared if the same spec resolves to a cached module. Use `swimmer._data` instead.

## Using ctx for Awareness

The `ctx` object lets behaviours react to the environment:

```lua
-- Avoid text: if the next position overlaps text, shift vertically
function SmartSwim:advance(swimmer, ctx)
  swimmer.col = swimmer.col + swimmer.speed * swimmer.dir

  local text = ctx.get_visible_text(math.floor(swimmer.row))
  local col = math.floor(swimmer.col)
  if col >= 0 and col < #text then
    local ch = text:sub(col + 1, col + 1)
    if ch ~= " " and ch ~= "" then
      swimmer.row = swimmer.row + (math.random() < 0.5 and -1 or 1)
    end
  end
end

-- React to other entities
function Schooling:advance(swimmer, ctx)
  -- Find nearest other entity, steer toward it
  for _, ent in ipairs(ctx.entities) do
    if ent ~= swimmer then
      -- ... flocking logic
    end
  end
end
```

## Writing a Target Behaviour

A target behaviour steers swimmers toward a specific location in the buffer — a word, a pattern, a cursor position, another entity — then resumes normal movement. The built-in `"target"` preset does this for Lua patterns, but you can write your own for any targeting logic.

A target behaviour has three phases:

1. **Acquire** — on first tick, scan the buffer (or entities, or any source) to pick a destination. Store it in `swimmer._data`.
2. **Steer** — each tick, move `col`/`row` toward the stored target.
3. **Release** — once the target is reached (or lost), switch to pass-through horizontal movement.

### Walkthrough: the built-in target preset

Here's how `behaviours/target.lua` implements each phase, annotated:

```lua
local M = {}

local Target = {}
Target.__index = Target

function Target:advance(swimmer, ctx)
  ---------------------------------------------------------
  -- PHASE 1: Acquire — runs once on the first tick
  ---------------------------------------------------------
  if not swimmer._data.target_col then
    local target = self:_find_target(swimmer, ctx)
    if target then
      swimmer._data.target_col = target.col
      swimmer._data.target_row = target.row
    else
      -- No match found — mark as "no target" so we don't search again
      swimmer._data.target_col = false
    end
  end

  ---------------------------------------------------------
  -- PHASE 3 (early exit): Release — horizontal pass-through
  ---------------------------------------------------------
  if swimmer._data.target_col == false then
    swimmer.col = swimmer.col + swimmer.speed * swimmer.dir
    return
  end

  ---------------------------------------------------------
  -- PHASE 2: Steer — move toward target each tick
  ---------------------------------------------------------
  local dx = swimmer._data.target_col - swimmer.col
  local dy = swimmer._data.target_row - swimmer.row

  -- Horizontal: move at swimmer.speed toward target column
  if math.abs(dx) > swimmer.speed then
    swimmer.col = swimmer.col + swimmer.speed * (dx > 0 and 1 or -1)
  else
    swimmer.col = swimmer._data.target_col
  end

  -- Vertical: drift at 0.5 rows/tick toward target row
  if math.abs(dy) > 0.5 then
    swimmer.row = swimmer.row + (dy > 0 and 0.5 or -0.5)
  end

  -- Check if we've arrived — switch to pass-through
  if math.abs(dx) <= swimmer.speed and math.abs(dy) <= 0.5 then
    swimmer._data.target_col = false
  end
end
```

The target search scans every visible row for the first pattern match:

```lua
function Target:_find_target(swimmer, ctx)
  for row = 0, ctx.win_height - 1 do
    local text = ctx.get_visible_text(row)
    for _, pat in ipairs(self.patterns) do
      local s = text:find(pat)
      if s then
        return { row = row, col = s - 1 }  -- 0-indexed column
      end
    end
  end
  return nil
end
```

The constructor builds the pattern list from user config, escaping literal words with `vim.pesc()`:

```lua
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
  return setmetatable({ patterns = patterns }, Target)
end
```

### Example: target the cursor

A behaviour that steers each swimmer toward the cursor position:

`lua/nvim-fish/behaviours/seek_cursor.lua`:

```lua
local M = {}

local SeekCursor = {}
SeekCursor.__index = SeekCursor

function SeekCursor:advance(swimmer, ctx)
  -- Acquire: get cursor position relative to viewport
  if not swimmer._data.target_col then
    local cursor = vim.api.nvim_win_get_cursor(ctx.win_info.win)
    -- cursor is {1-indexed row, 0-indexed col}
    local cursor_row = cursor[1] - ctx.win_info.top  -- viewport-relative
    local cursor_col = cursor[2]

    if cursor_row >= 0 and cursor_row < ctx.win_height then
      swimmer._data.target_col = cursor_col
      swimmer._data.target_row = cursor_row
    else
      swimmer._data.target_col = false
    end
  end

  -- Release: pass-through
  if swimmer._data.target_col == false then
    swimmer.col = swimmer.col + swimmer.speed * swimmer.dir
    return
  end

  -- Steer
  local dx = swimmer._data.target_col - swimmer.col
  local dy = swimmer._data.target_row - swimmer.row

  if math.abs(dx) > swimmer.speed then
    swimmer.col = swimmer.col + swimmer.speed * (dx > 0 and 1 or -1)
  else
    swimmer.col = swimmer._data.target_col
  end

  if math.abs(dy) > 0.5 then
    swimmer.row = swimmer.row + (dy > 0 and 0.5 or -0.5)
  end

  if math.abs(dx) <= swimmer.speed and math.abs(dy) <= 0.5 then
    swimmer._data.target_col = false
  end
end

function M.new(opts)
  return setmetatable({}, SeekCursor)
end

return M
```

### Example: target another entity

A behaviour that chases the nearest other swimmer, then passes through:

```lua
function ChaseEntity:advance(swimmer, ctx)
  -- Re-acquire every 5 ticks (target moves)
  if not swimmer._data.chase_col or swimmer.age % 5 == 0 then
    local nearest, min_dist = nil, math.huge
    for _, ent in ipairs(ctx.entities) do
      if ent ~= swimmer then
        local d = math.abs(ent.col - swimmer.col) + math.abs(ent.row - swimmer.row)
        if d < min_dist then
          nearest = ent
          min_dist = d
        end
      end
    end

    if nearest then
      swimmer._data.chase_col = nearest.col
      swimmer._data.chase_row = nearest.row
    else
      swimmer._data.chase_col = false
    end
  end

  if swimmer._data.chase_col == false then
    swimmer.col = swimmer.col + swimmer.speed * swimmer.dir
    return
  end

  -- Steer (same pattern as target.lua)
  local dx = swimmer._data.chase_col - swimmer.col
  local dy = swimmer._data.chase_row - swimmer.row

  if math.abs(dx) > swimmer.speed then
    swimmer.col = swimmer.col + swimmer.speed * (dx > 0 and 1 or -1)
  else
    swimmer.col = swimmer._data.chase_col
  end

  if math.abs(dy) > 0.5 then
    swimmer.row = swimmer.row + (dy > 0 and 0.5 or -0.5)
  end
end
```

Note the difference from the built-in `target`: this re-acquires every 5 ticks because the chase target moves. The built-in `target` acquires once because buffer text is static.

### Design tips for target behaviours

- **Acquire once vs. continuously**: scan once in `_data` initialization for static targets (words, patterns). Re-scan periodically for moving targets (cursor, other entities).
- **Always handle "no target"**: set `swimmer._data.target_col = false` and fall back to horizontal movement. A fish that freezes because it found nothing looks like a bug.
- **Steering speed**: use `swimmer.speed` for horizontal and a fixed constant (0.5 works well) for vertical. This keeps movement feeling natural at any spawn speed.
- **Use `_data`, not `self`**: multiple swimmers share the same behaviour instance. Per-swimmer targets must go in `swimmer._data`.
- **Off-screen removal**: the default off-screen check still applies unless you define `is_done`. After releasing from a target, the swimmer will eventually swim off the edge and be cleaned up automatically.

## Quick Reference

| Want to... | Do this |
|---|---|
| Change movement for all fish | `setup({ behaviour = "sine" })` |
| Use preset with options | `setup({ behaviour = { "sine", amplitude = 3 } })` |
| Write a custom dx/dy function | `setup({ behaviour = function(tick, s, ctx) return dx, dy end })` |
| Use a raw behaviour table | `setup({ behaviour = { advance = function(self, s, ctx) ... end } })` |
| Add new sprites | `setup({ species = { name = { sprites = { right = ..., left = ... } } } })` |
| Multiple species at once | `setup({ species = { a = { ... }, b = { ... } } })` |
| Create a reusable preset | Add module in `behaviours/`, register in `behaviours/init.lua` |
| Store per-swimmer state | Use `swimmer._data` |
| Control swimmer lifetime | Implement `is_done(self, swimmer, ctx)` on your behaviour |
