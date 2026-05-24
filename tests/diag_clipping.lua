-- tests/diag_clipping.lua — Visual diagnostic for fish clipping
--
-- Opens a scratch buffer with known text patterns, spawns a fish at a
-- fixed position, and prints a report comparing:
--   1. What line_text `place_clipped` receives
--   2. What segments it produces
--   3. What `virt_text_win_col` values the extmarks actually get
--   4. What the buffer line content actually is at each row
--
-- Usage from Neovim:  :luafile tests/diag_clipping.lua
-- Or:                 :FishDiag

local engine = require("nvim-fish.engine")
local place_clipped = engine._place_clipped

local ns_diag = vim.api.nvim_create_namespace("nvim_fish_diag")

local function run_diag()
  -- Stop fish animation if running to avoid interference
  if engine.is_running() then
    engine.stop()
    print("[diag] Stopped running fish animation")
  end

  -- Create a scratch buffer with known content
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"

  -- Known test lines — each has text at specific columns
  -- Using dots to make whitespace visible in the report
  local test_lines = {
    "",                           -- row 0: empty
    "hello",                      -- row 1: text at cols 0-4
    "     world",                 -- row 2: spaces 0-4, text 5-9
    "ab     cd",                  -- row 3: text, gap, text
    "  x  x  ",                   -- row 4: scattered single chars
    "the quick brown fox",        -- row 5: full text
    "",                           -- row 6: empty
    "   gap   here   ",           -- row 7: multiple words with gaps
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, test_lines)

  -- Get window info to understand coordinate space
  local win = vim.api.nvim_get_current_win()
  local win_width = vim.api.nvim_win_get_width(win)
  local win_info = vim.fn.getwininfo(win)[1]
  local textoff = win_info.textoff

  print("=== Fish Clipping Diagnostic ===\n")
  print(string.format("Window width (nvim_win_get_width): %d", win_width))
  print(string.format("Text offset (signcolumn+number etc): %d", textoff))
  print(string.format("Usable text area: %d columns", win_width - textoff))
  print("")

  -- Test sprite
  local sprite = "><>"
  local hl = "NvimFish"

  -- Place fish at several fixed positions on each row
  local test_cols = { 0, 3, 5, 10 }

  for row_idx, line in ipairs(test_lines) do
    local row = row_idx - 1 -- 0-indexed
    print(string.format("--- Row %d: %q (len=%d bytes) ---", row, line, #line))

    for _, fish_col in ipairs(test_cols) do
      -- This is what the engine does:
      -- 1. get_line_text returns the raw buffer line
      -- 2. place_clipped receives fish_col (display col) and line text
      local segments = place_clipped(fish_col, sprite, hl, line)

      -- Format segments for display
      local seg_strs = {}
      for _, seg in ipairs(segments) do
        local text = ""
        for _, chunk in ipairs(seg.chunks) do
          text = text .. chunk[1]
        end
        table.insert(seg_strs, string.format("col=%d:%q", seg.col, text))
      end
      local seg_desc = #seg_strs > 0 and table.concat(seg_strs, ", ") or "(fully clipped)"

      -- What SHOULD happen? Check each sprite position manually
      local expected = {}
      for i = 1, #sprite do
        local c = fish_col + i - 1
        local ch = ""
        if c >= 0 and c < #line then
          ch = line:sub(c + 1, c + 1)
        end
        local should_show = (ch == "" or ch == " " or ch == "\t")
        table.insert(expected, string.format(
          "col%d=%s(%s)",
          c,
          should_show and "SHOW" or "CLIP",
          ch == "" and "empty" or string.format("%q", ch)
        ))
      end

      print(string.format(
        "  fish@col=%d → %s  |  per-char: %s",
        fish_col, seg_desc, table.concat(expected, " ")
      ))
    end
    print("")
  end

  -- Now actually place extmarks and let the user see them
  print("=== Placing visual markers (fish at col=3 on each row) ===")
  print("Look at the buffer — fish should be visible on whitespace, hidden on text.\n")

  vim.api.nvim_buf_clear_namespace(buf, ns_diag, 0, -1)

  local fish_col = 3
  for row_idx, line in ipairs(test_lines) do
    local buf_row = row_idx - 1
    local segments = place_clipped(fish_col, sprite, hl, line)
    for _, seg in ipairs(segments) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns_diag, buf_row, 0, {
        virt_text = seg.chunks,
        virt_text_win_col = seg.col,
        virt_text_pos = "overlay",
        priority = 1,
      })
    end

    -- Also mark where the text actually is with a different highlight
    local visible = {}
    for i = 1, #line do
      local ch = line:sub(i, i)
      if ch ~= " " then
        table.insert(visible, i - 1) -- 0-indexed display col (ASCII assumption)
      end
    end
    if #visible > 0 then
      print(string.format(
        "  Row %d: text at display cols {%s}, fish extmarks at col=%d",
        buf_row,
        table.concat(vim.tbl_map(tostring, visible), ","),
        fish_col
      ))
    else
      print(string.format("  Row %d: empty line, fish at col=%d", buf_row, fish_col))
    end
  end

  -- === Programmatic verification ===
  -- Read back all extmarks and check if any virt_text_win_col overlaps
  -- a non-whitespace character in the buffer line
  print("\n=== Programmatic extmark verification ===")

  local extmarks = vim.api.nvim_buf_get_extmarks(buf, ns_diag, 0, -1, { details = true })
  local violations = 0

  for _, em in ipairs(extmarks) do
    local em_row = em[2]          -- 0-indexed buffer row
    local details = em[4]
    local vt_col = details.virt_text_win_col
    local vt_chunks = details.virt_text or {}

    -- Get the buffer line at this row
    local line = test_lines[em_row + 1] or ""

    -- Check each character of the virtual text
    local vt_text = ""
    for _, chunk in ipairs(vt_chunks) do
      vt_text = vt_text .. chunk[1]
    end

    for i = 1, #vt_text do
      local display_col = vt_col + i - 1
      -- What character is at this display column in the buffer?
      local buf_char = ""
      if display_col >= 0 and display_col < #line then
        buf_char = line:sub(display_col + 1, display_col + 1)
      end
      local is_whitespace = (buf_char == "" or buf_char == " " or buf_char == "\t")
      if not is_whitespace then
        violations = violations + 1
        print(string.format(
          "  VIOLATION row=%d: extmark char %q at virt_text_win_col=%d overlaps buffer char %q",
          em_row, vt_text:sub(i, i), display_col, buf_char
        ))
      end
    end
  end

  if violations == 0 then
    print("  No violations — all extmarks are on whitespace (byte-level check)")
  else
    print(string.format("  %d violation(s) found!", violations))
  end

  -- === Check: does virt_text_win_col actually mean what we think? ===
  -- Place a known marker and use screenpos to verify alignment
  print("\n=== Coordinate system probe ===")
  print(string.format("  textoff = %d (gutter width)", textoff))
  print("  If virt_text_win_col=0 renders at screen column %d, then", textoff + 1)
  print("  virt_text_win_col is text-area-relative (no adjustment needed).")
  print("  If it renders at screen column 1, then virt_text_win_col is window-relative")
  print("  and we need to subtract textoff from line_text indexing.")
  print("")
  print("  To verify: look at Row 0 (empty line) — the ><> fish at col=3.")
  print("  Count from the left edge of the TEXT area (after line numbers).")
  print("  Is the '>' at position 3 (0-indexed) from the text area start? → correct")
  print("  Or is it at position 3 from the window edge (overlapping line numbers)? → bug")

  print("\n=== IMPORTANT: Visually verify in the buffer above ===")
  print("  - Fish chars should NOT appear on top of letters")
  print("  - Fish chars SHOULD appear on empty/space positions")
  print("  - If you see overlap, the bug is in coordinate mapping, not place_clipped logic")
end

-- Register as a command
vim.api.nvim_create_user_command("FishDiag", function()
  run_diag()
end, { desc = "Run fish clipping visual diagnostic" })

-- Auto-run when sourced
run_diag()
