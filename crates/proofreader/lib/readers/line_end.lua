class 'LineEndReader' extends 'BasicReader'

function LineEndReader:proofread(tokens, lines, source)
  if self.config['Enabled'] == false then return true end

  local line_ending = self.config['LineEnding']

  if line_ending == '\n' then
    return source:include('\r\n')
  else
    return source:match('[^\r]\n')
  end
end

function LineEndReader:message()
  return "Incorrect or inconsistent line endings, use '"..(self.config['LineEndings'] or '\n'):escape().."'."
end
