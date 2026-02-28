-- tests/test_tabs.lua — Check how place_clipped handles tabs
-- Run: nvim --headless -u NONE -c "set rtp+=." -c "luafile tests/test_tabs.lua" -c "qa!"

local engine = require("nvim-fish.engine")
local place_clipped = engine._place_clipped
local expand_tabs = engine._expand_tabs

local tabstop = vim.bo.tabstop
print("=== Tab clipping test (with expand_tabs fix) ===")
print("tabstop = " .. tabstop)

-- Simulate a JSON line: two tabs then "key": "value"
-- Raw: \t\t"key": "value"
local tab_line_raw = '\t\t"key": "value"'
local tab_line = expand_tabs(tab_line_raw, tabstop)
print(string.format("\nRaw line: %q", tab_line_raw))
print(string.format("Expanded line: %q", tab_line))
print(string.format("Byte length (raw): %d", #tab_line_raw))
print(string.format("Byte length (expanded): %d", #tab_line))
print(string.format("Display width: %d", vim.fn.strdisplaywidth(tab_line_raw)))

-- Show byte-by-byte
print("\nByte map:")
for i = 1, #tab_line do
  local b = tab_line:sub(i, i)
  print(string.format("  byte[%d] = %q (0x%02x)", i - 1, b, b:byte()))
end

-- Show display column map (expand tabs)
local expanded = tab_line:gsub("\t", string.rep(" ", tabstop))
print(string.format("\nExpanded (tabs→spaces): %q", expanded))
print(string.format("Expanded length: %d", #expanded))

print("\nDisplay column → actual visual character:")
for i = 0, #expanded - 1 do
  local ch = expanded:sub(i + 1, i + 1)
  local ws = (ch == " ") and "whitespace" or "TEXT"
  print(string.format("  dcol %2d = %q  (%s)", i, ch, ws))
end

-- Now test place_clipped at various display columns
print("\n=== place_clipped results vs expected ===")
print("(place_clipped uses byte indexing, expected uses display columns)\n")

local sprite = "><>"
local hl = "NvimFish"

local any_mismatch = false

for _, col in ipairs({0, 3, 5, 8, 10, 14, 16, 20}) do
  local segs = place_clipped(col, sprite, hl, tab_line)

  -- What place_clipped actually produced (actual)
  local actual_vis = {}
  for ci = 0, #sprite - 1 do
    actual_vis[ci] = false -- clipped by default
  end
  for _, seg in ipairs(segs) do
    local t = ""
    for _, chunk in ipairs(seg.chunks) do t = t .. chunk[1] end
    for ci = 0, #t - 1 do
      local offset = seg.col - col + ci
      if offset >= 0 and offset < #sprite then
        actual_vis[offset] = true -- shown
      end
    end
  end

  -- What SHOULD happen (based on display columns)
  local expected_vis = {}
  for ci = 0, #sprite - 1 do
    local dcol = col + ci
    local ch = ""
    if dcol < #expanded then
      ch = expanded:sub(dcol + 1, dcol + 1)
    end
    expected_vis[ci] = (ch == "" or ch == " ")
  end

  -- Compare
  local mismatch = false
  local details = {}
  for ci = 0, #sprite - 1 do
    local dcol = col + ci
    local act = actual_vis[ci] and "SHOW" or "CLIP"
    local exp = expected_vis[ci] and "SHOW" or "CLIP"
    local mark = ""
    if act ~= exp then
      mismatch = true
      any_mismatch = true
      mark = " ← MISMATCH!"
    end
    local dch = ""
    if dcol < #expanded then dch = expanded:sub(dcol + 1, dcol + 1) end
    table.insert(details, string.format(
      "    dcol %2d: visual=%q  got=%s  want=%s%s",
      dcol, dch, act, exp, mark
    ))
  end

  local status = mismatch and "FAIL" or "ok"
  print(string.format("  fish@dcol=%d [%s]", col, status))
  for _, d in ipairs(details) do
    print(d)
  end
end

if any_mismatch then
  print("\n!!! MISMATCHES FOUND — tabs cause byte/display column confusion !!!")
else
  print("\nAll correct — no mismatches.")
end
