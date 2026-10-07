class 'LineEndReader' extends 'BasicReader'

--- Checks the line endings of the code against the reader's 'LineEnding' option.
-- @param tokens [Array<Hash> unused]
-- @param lines [Array<String> unused]
-- @param source [String the code]
-- @return [Boolean/Number/String truthy if the check passes (true when the reader is
--   disabled, otherwise the result of the string search), nil if it fails]
function LineEndReader:proofread(tokens, lines, source)
  if self.config['Enabled'] == false then return true end

  local line_ending = self.config['LineEnding']

  if line_ending == '\n' then
    return source:include('\r\n')
  else
    return source:match('[^\r]\n')
  end
end

--- Returns the message that describes a line ending offense.
-- @return [String]
function LineEndReader:message()
  return "Incorrect or inconsistent line endings, use '"..(self.config['LineEndings'] or '\n'):escape().."'."
end
