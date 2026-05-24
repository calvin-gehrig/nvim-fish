-- nvim-fish/engine.lua — Generic Background Animation Engine

local M = {}

local ns = vim.api.nvim_create_namespace("nvim_fish")
local timer = nil
local entities = {}
local spawners = {}
local running = false
local tick_ms = 150
local tick_count = 0

function M.register_spawner(fn)
  table.insert(spawners, fn)
end

function M.is_running()
  return running
end

--- Read visible window geometry
local function get_window_info()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local top = vim.fn.line("w0") -- 1-indexed
  local bot = vim.fn.line("w$")
  local width = vim.api.nvim_win_get_width(win)
  return { buf = buf, win = win, top = top, bot = bot, width = width }
end

--- Get the display text of a buffer line (0-indexed row).
--- Returns empty string if line doesn't exist.
local function get_line_text(buf, lnum)
  local lines = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, false)
  return lines[1] or ""
end

--- Expand tabs in a string to spaces, respecting tabstop alignment.
--- After expansion, byte positions equal display columns (for ASCII content).
local function expand_tabs(s, tabstop)
  local result = {}
  local col = 0
  for i = 1, #s do
    local ch = s:sub(i, i)
    if ch == "\t" then
      local spaces = tabstop - (col % tabstop)
      table.insert(result, string.rep(" ", spaces))
      col = col + spaces
    else
      table.insert(result, ch)
      col = col + 1
    end
  end
  return table.concat(result)
end

--- Place a sprite with text-clipping.
--- Returns a list of segments, each { col, chunks } for one extmark.
--- line_text must be tab-expanded so byte positions equal display columns.
--- @package Exposed for testing as M._place_clipped
local function place_clipped(col, sprite, hl, line_text)
  local segments = {}
  local cur_col = nil
  local cur_text = nil

  for i = 1, #sprite do
    local c = col + i - 1
    -- Check if this column overlaps real (non-whitespace) text
    local overlaps = false
    if c >= 0 and c < #line_text then
      local ch = line_text:sub(c + 1, c + 1)
      if ch ~= " " and ch ~= "" then
        overlaps = true
      end
    end

    if not overlaps then
      if cur_col == nil then
        -- Start a new segment
        cur_col = c
        cur_text = sprite:sub(i, i)
      else
        -- Extend current segment
        cur_text = cur_text .. sprite:sub(i, i)
      end
    else
      -- Gap — finalize current segment if any
      if cur_col ~= nil then
        table.insert(segments, { col = cur_col, chunks = { { cur_text, hl } } })
        cur_col = nil
        cur_text = nil
      end
    end
  end

  -- Finalize last segment
  if cur_col ~= nil then
    table.insert(segments, { col = cur_col, chunks = { { cur_text, hl } } })
  end

  return segments
end

local function tick()
  -- Must run in vim context
  vim.schedule(function()
    if not running then
      return
    end

    local ok, err = pcall(function()
      local info = get_window_info()
      local buf = info.buf
      local win_height = info.bot - info.top + 1

      tick_count = tick_count + 1

      -- Build context object
      local ctx = {
        win_width = info.width,
        win_height = win_height,
        win_info = info,
        entities = entities,
        tick = tick_count,
        get_visible_text = function(row)
          local buf_row = row + info.top - 1 -- 0-indexed buffer line
          return get_line_text(buf, buf_row)
        end,
      }

      -- Clear all previous extmarks
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

      -- Call spawners
      for _, spawner in ipairs(spawners) do
        local new_entity = spawner(ctx)
        if new_entity then
          table.insert(entities, new_entity)
        end
      end

      -- Update entities (remove dead ones)
      local alive = {}
      for _, ent in ipairs(entities) do
        local keep = ent:update(ctx)
        if keep then
          table.insert(alive, ent)
        end
      end
      entities = alive

      -- Render entities
      local tabstop = vim.bo[buf].tabstop
      for _, ent in ipairs(entities) do
        local r = ent:render()
        if r then
          -- r = {row, col, sprite, hl}
          -- row is relative to visible window (0-indexed from window top)
          -- sprite may contain newlines for multiline entities
          local sprite_lines = vim.split(r.sprite, "\n", { plain = true })
          local line_count = vim.api.nvim_buf_line_count(buf)

          for li, sprite_line in ipairs(sprite_lines) do
            local buf_row = (r.row + li - 1) + info.top - 1 -- 0-indexed buffer line
            if buf_row >= 0 and buf_row < line_count and #sprite_line > 0 then
              local line_text = expand_tabs(get_line_text(buf, buf_row), tabstop)
              local segments = place_clipped(r.col, sprite_line, r.hl, line_text)
              for _, seg in ipairs(segments) do
                pcall(vim.api.nvim_buf_set_extmark, buf, ns, buf_row, 0, {
                  virt_text = seg.chunks,
                  virt_text_win_col = seg.col,
                  virt_text_pos = "overlay",
                  priority = 1,
                  ephemeral = false,
                })
              end
            end
          end
        end
      end
    end)

    if not ok then
      -- Silently ignore errors (e.g. buffer closed)
    end
  end)
end

function M.start(opts)
  if running then
    return
  end
  tick_ms = (opts and opts.tick_ms) or tick_ms
  running = true

  timer = vim.uv.new_timer()
  timer:start(0, tick_ms, tick)
end

function M.stop()
  if not running then
    return
  end
  running = false

  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end

  -- Clear extmarks in current buffer
  vim.schedule(function()
    pcall(function()
      local buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end)
  end)

  entities = {}
  tick_count = 0
end

function M.toggle(opts)
  if running then
    M.stop()
  else
    M.start(opts)
  end
end

function M.entity_count()
  return #entities
end

-- Expose internals for testing
M._place_clipped = place_clipped
M._expand_tabs = expand_tabs

return M
