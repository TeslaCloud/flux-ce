-- Methology is largely copied from LuaJIT's source code.
-- https://github.com/LuaJIT/LuaJIT/blob/master/src/lj_char.h
--
-- Used to determine character types, useful in text parsing.
--

local char = {}

-- Slightly ripped bitmasks from lj_char.h
CHAR_CNTRL = 0x01
CHAR_SPACE = 0x02
CHAR_PUNCT = 0x04
CHAR_DIGIT = 0x08
CHAR_HEX   = 0x10
CHAR_IDENT = 0x20
CHAR_LOWER = 0x40
CHAR_UPPER = 0x80

-- Auto-generated ASCII characters table (0-255).
local CHARS_TABLE = {
  [0] = 0,
  1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2,
  36, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 56,
  56, 56, 56, 56, 56, 56, 56, 56, 56, 4, 4, 4, 4, 4, 36, 4,
  176, 176, 176, 176, 176, 176, 160, 160, 160, 160, 160, 160, 160, 160, 160, 160,
  160, 160, 160, 160, 160, 160, 160, 160, 160, 160, 4, 4, 4, 4, 36, 4,
  112, 112, 112, 112, 112, 112, 96, 96, 96, 96, 96, 96, 96, 96, 96, 96,
  96, 96, 96, 96, 96, 96, 96, 96, 96, 96, 4, 4, 4, 4, 1, 32,
  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,
  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
}

function char.is(c, t)
  if !isnumber(c) then return false end

  return tobool(bit.band(CHARS_TABLE[c], t))
end

function char.is_num(c)   return char.is(c, CHAR_DIGIT) end
function char.is_hex(c)   return char.is(c, CHAR_HEX)   end
function char.is_ident(c) return char.is(c, CHAR_IDENT) end
function char.is_space(c) return char.is(c, CHAR_SPACE) end
function char.is_lower(c) return char.is(c, CHAR_LOWER) end
function char.is_upper(c) return char.is(c, CHAR_UPPER) end
function char.is_punct(c) return char.is(c, CHAR_PUNCT) end
function char.is_cntrl(c) return char.is(c, CHAR_CNTRL) end

return char
