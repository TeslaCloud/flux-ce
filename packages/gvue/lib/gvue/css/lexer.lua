local function tokenize(text)
  local buf = ''
  local output = {}

  text = text:gsub('#{([^}]+)}', function(code)
    local res = CompileString('return ('..code..')', '_css_interpolated')()
    return res != nil and tostring(res) or ''
  end)

  local function dump()
    if buf and buf != '' then
      table.insert(output, buf)
      buf = ''
    end
  end

  for i = 1, text:len() do
    local cur = text[i]

    -- ignore spaces, dump if necessary
    if cur == ' ' or cur == '\t' or cur == ';' or cur == '\n' then
      dump()
      if cur == ';' then
        buf = ';'
        dump()
      end
      continue
    end

    if buf:match('^[^a-zA-Z0-9_%-]$') then
      dump()
    end

    if buf != '' and !cur:match('[%w_%-%%]') then
      dump()
    end

    buf = buf..cur
  end

  return output
end

return { tokenize = tokenize }
