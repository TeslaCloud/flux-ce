class 'LineLengthReader' extends 'BasicReader'

--- Checks that no line is longer than the reader's 'Max' option (120 by default).
-- The position and the line number are returned only when a line is too long.
-- @param tokens [Array<Hash> unused]
-- @param lines [Array<String> the code split into lines]
-- @param source [String the code]
-- @return [Boolean whether all lines fit, Number character offset of the offending line,
--   Number its line number]
function LineLengthReader:proofread(tokens, lines, source)
  if self.config['Enabled'] == false then return true end
  if !lines or #lines == 0 or source:len() < 1 then return true end

  self.config['Max'] = self.config['Max'] or 120

  local max_length = self.config['Max']
  local cur_pos = 0

  for line_num, line in ipairs(lines) do
    local line_len = line:len()

    if line_len > max_length then
      self.line_length = line_len
      return false, cur_pos, line_num
    end

    cur_pos = cur_pos + line_len + 1
  end

  return true
end

--- Checks whether the offending code should be pointed at in the message.
-- @return [Boolean always true]
function LineLengthReader:should_point()
  return true
end

--- Returns the severity of line length offenses.
-- @return [String always 'critical']
function LineLengthReader:severity()
  return 'critical'
end

--- Returns the message that describes the last line length offense.
-- @return [String]
function LineLengthReader:message()
  return "Line exceeds maximum line length ("..self.line_length.." / "..self.config['Max']..")"
end
