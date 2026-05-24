-- tests/test_clipping.lua — Unit tests for place_clipped()
--
-- Run from Neovim:   :luafile tests/test_clipping.lua
-- Run from shell:    nvim --headless -u NONE -c "set rtp+=." -c "luafile tests/test_clipping.lua" -c "qa!"

local engine = require("nvim-fish.engine")
local place_clipped = engine._place_clipped

local pass_count = 0
local fail_count = 0

--- Assert helper: compare segments against expected.
--- expected: list of { col = N, text = "..." }
local function check(name, segments, expected)
  local ok = true

  if #segments ~= #expected then
    ok = false
  else
    for i, exp in ipairs(expected) do
      local seg = segments[i]
      if seg.col ~= exp.col then
        ok = false
        break
      end
      -- Extract text from chunks
      local actual_text = ""
      for _, chunk in ipairs(seg.chunks) do
        actual_text = actual_text .. chunk[1]
      end
      if actual_text ~= exp.text then
        ok = false
        break
      end
    end
  end

  if ok then
    pass_count = pass_count + 1
    print("  PASS: " .. name)
  else
    fail_count = fail_count + 1
    print("  FAIL: " .. name)
    print("    expected " .. #expected .. " segment(s):")
    for i, exp in ipairs(expected) do
      print(string.format("      [%d] col=%d text=%q", i, exp.col, exp.text))
    end
    print("    got " .. #segments .. " segment(s):")
    for i, seg in ipairs(segments) do
      local t = ""
      for _, chunk in ipairs(seg.chunks) do
        t = t .. chunk[1]
      end
      print(string.format("      [%d] col=%d text=%q", i, seg.col, t))
    end
  end
end

print("=== place_clipped unit tests (ASCII only) ===\n")

local HL = "NvimFish"

-- Test 1: Sprite on empty line → fully visible
do
  local segs = place_clipped(5, "><>", HL, "")
  check("empty line → full sprite visible", segs, {
    { col = 5, text = "><>" },
  })
end

-- Test 2: Sprite on all-spaces line → fully visible
do
  local segs = place_clipped(2, "><>", HL, "          ")
  check("all-spaces line → full sprite visible", segs, {
    { col = 2, text = "><>" },
  })
end

-- Test 3: Sprite fully overlapping text → no segments
do
  local segs = place_clipped(0, "><>", HL, "hello world")
  check("fully overlapping text → no segments", segs, {})
end

-- Test 4: Sprite to the right of all text → fully visible
do
  local segs = place_clipped(12, "><>", HL, "hello world")
  check("sprite past end of text → full sprite visible", segs, {
    { col = 12, text = "><>" },
  })
end

-- Test 5: Sprite partially overlapping text on left edge
-- line: "hi      " (h at 0, i at 1, spaces from 2+)
-- fish at col=1, sprite "><>": positions 1,2,3
-- col 1 = 'i' → clipped; col 2 = ' ' → visible; col 3 = ' ' → visible
do
  local segs = place_clipped(1, "><>", HL, "hi        ")
  check("overlap text on left edge → partial clip", segs, {
    { col = 2, text = "<>" },
  })
end

-- Test 6: Sprite partially overlapping text on right edge
-- line: "     hello"
-- fish at col=3, sprite "><>": positions 3,4,5
-- col 3 = ' ' → visible; col 4 = ' ' → visible; col 5 = 'h' → clipped
do
  local segs = place_clipped(3, "><>", HL, "     hello")
  check("overlap text on right edge → partial clip", segs, {
    { col = 3, text = "><" },
  })
end

-- Test 7: Sprite spans a gap in text
-- line: "a   b"
-- fish at col=0, sprite "><>>>" (5 chars): positions 0,1,2,3,4
-- col 0 = 'a' → clipped; col 1,2,3 = ' ' → visible; col 4 = 'b' → clipped
do
  local segs = place_clipped(0, "><>>>", HL, "a   b")
  check("text gap in middle → split into segments", segs, {
    { col = 1, text = "<>>" },
  })
end

-- Test 8: Sprite entirely in whitespace between two words
-- line: "ab     cd"
-- fish at col=3, sprite "><>": positions 3,4,5 → all spaces
do
  local segs = place_clipped(3, "><>", HL, "ab     cd")
  check("sprite in whitespace gap → fully visible", segs, {
    { col = 3, text = "><>" },
  })
end

-- Test 9: Single-char overlaps splitting sprite into 3 segments
-- line: "  x  x  "
-- fish at col=1, sprite "><>>><" (6 chars): positions 1,2,3,4,5,6
-- col 1 = ' ' visible; col 2 = 'x' clipped; col 3,4 = ' ' visible; col 5 = 'x' clipped; col 6 = ' ' visible
do
  local segs = place_clipped(1, "><>>><", HL, "  x  x  ")
  check("two single-char obstacles → 3 segments", segs, {
    { col = 1, text = ">" },
    { col = 3, text = ">>" },
    { col = 6, text = "<" },
  })
end

-- Test 10: Sprite at col=0 on empty line
do
  local segs = place_clipped(0, "><>", HL, "")
  check("col=0 on empty line → full sprite visible", segs, {
    { col = 0, text = "><>" },
  })
end

print(string.format("\n=== Results: %d passed, %d failed ===", pass_count, fail_count))
if fail_count > 0 then
  print("!!! SOME TESTS FAILED — clipping logic has issues !!!")
else
  print("All tests passed.")
end
