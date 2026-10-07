-- Methodology is largely copied from LuaJIT's source code.
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

--- Checks whether a character belongs to a character class.
-- @param c [Number character code (0-255), as returned by string.byte]
-- @param t [Number character class, one of the CHAR_* bitmasks]
-- @return [Boolean false if c is not a number]
function char.is(c, t)
  if !isnumber(c) then return false end

  return tobool(bit.band(CHARS_TABLE[c], t))
end

--- Checks whether a character is a decimal digit.
-- @param c [Number character code]
-- @return [Boolean]
function char.is_num(c)   return char.is(c, CHAR_DIGIT) end

--- Checks whether a character is a hexadecimal digit.
-- @param c [Number character code]
-- @return [Boolean]
function char.is_hex(c)   return char.is(c, CHAR_HEX)   end

--- Checks whether a character can be a part of an identifier: a letter, a digit, '_',
-- '!', '?' or any byte above 127.
-- @param c [Number character code]
-- @return [Boolean]
function char.is_ident(c) return char.is(c, CHAR_IDENT) end

--- Checks whether a character is a space or a tab.
-- @param c [Number character code]
-- @return [Boolean]
function char.is_space(c) return char.is(c, CHAR_SPACE) end

--- Checks whether a character is a lowercase letter.
-- @param c [Number character code]
-- @return [Boolean]
function char.is_lower(c) return char.is(c, CHAR_LOWER) end

--- Checks whether a character is an uppercase letter.
-- @param c [Number character code]
-- @return [Boolean]
function char.is_upper(c) return char.is(c, CHAR_UPPER) end

--- Checks whether a character is a punctuation character.
-- @param c [Number character code]
-- @return [Boolean]
function char.is_punct(c) return char.is(c, CHAR_PUNCT) end

--- Checks whether a character is a control character.
-- @param c [Number character code]
-- @return [Boolean]
function char.is_cntrl(c) return char.is(c, CHAR_CNTRL) end

return char
