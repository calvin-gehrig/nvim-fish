-- nvim-fish/engine.lua — Generic Background Animation Engine

local M = {}

local ns = vim.api.nvim_create_namespace("nvim_fish")
local timer = nil
local entities = {}
local spawners = {}
local running = false
local tick_ms = 150

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

--- Place a sprite with text-clipping.
--- row: 0-indexed buffer line
--- col: 0-indexed window column
--- sprite: the ASCII string to render
--- hl: highlight group name
--- Returns extmark params or nil if fully clipped.
local function place_clipped(buf, row, col, sprite, hl, line_text)
  local chunks = {}
  local first_col = nil

  for i = 1, #sprite do
    local c = col + i - 1
    -- Check if this column overlaps real (non-whitespace) text
    local overlaps = false
    if c < #line_text then
      local ch = line_text:sub(c + 1, c + 1)
      if ch ~= " " and ch ~= "\t" and ch ~= "" then
        overlaps = true
      end
    end

    if not overlaps then
      if first_col == nil then
        first_col = c
      end
      -- Merge with previous chunk if same hl and contiguous
      if #chunks > 0 then
        local last = chunks[#chunks]
        -- Always same hl, just append
        chunks[#chunks] = { last[1] .. sprite:sub(i, i), last[2] }
      else
        chunks[1] = { sprite:sub(i, i), hl }
      end
    else
      -- Gap — next visible char starts a new chunk
      if #chunks > 0 or first_col ~= nil then
        -- We need to account for the gap by inserting padding
        -- Actually with virt_text_win_col we set the start column,
        -- but subsequent chars just flow. We need a different approach:
        -- pad with spaces for gaps.
        if #chunks > 0 then
          local last = chunks[#chunks]
          chunks[#chunks] = { last[1] .. " ", last[2] }
        end
      end
    end
  end

  if first_col == nil or #chunks == 0 then
    return nil
  end

  return first_col, chunks
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

      -- Clear all previous extmarks
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

      -- Call spawners
      for _, spawner in ipairs(spawners) do
        local new_entity = spawner(info)
        if new_entity then
          table.insert(entities, new_entity)
        end
      end

      -- Update entities (remove dead ones)
      local alive = {}
      for _, ent in ipairs(entities) do
        local keep = ent:update(info.width, info.bot - info.top + 1)
        if keep then
          table.insert(alive, ent)
        end
      end
      entities = alive

      -- Render entities
      for _, ent in ipairs(entities) do
        local r = ent:render()
        if r then
          -- r = {row, col, sprite, hl}
          -- row is relative to visible window (0-indexed from window top)
          local buf_row = r.row + info.top - 1 -- convert to 0-indexed buffer line
          local line_count = vim.api.nvim_buf_line_count(buf)
          if buf_row >= 0 and buf_row < line_count then
            local line_text = get_line_text(buf, buf_row)
            local first_col, chunks = place_clipped(buf, buf_row, r.col, r.sprite, r.hl, line_text)
            if first_col and chunks then
              pcall(vim.api.nvim_buf_set_extmark, buf, ns, buf_row, 0, {
                virt_text = chunks,
                virt_text_win_col = first_col,
                virt_text_pos = "overlay",
                priority = 1,
                ephemeral = false,
              })
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

return M
