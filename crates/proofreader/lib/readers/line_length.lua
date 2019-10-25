class 'LineLengthReader' extends 'BasicReader'

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

function LineLengthReader:should_point()
  return true
end

function LineLengthReader:severity()
  return 'critical'
end

function LineLengthReader:message()
  return "Line exceeds maximum line length ("..self.line_length.." / "..self.config['Max']..")"
end
