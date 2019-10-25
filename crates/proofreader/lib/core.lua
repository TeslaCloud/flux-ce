do
  local peek_length = 16

  function PR:shoot_left(code, from_where)
    local str = ''

    for i = 1, peek_length do
      local v = code[from_where - i]

      if v == '\n' or (from_where - i) < 1 then
        break
      end

      str = v..str
    end

    return str
  end

  function PR:shoot_right(code, from_where)
    local str = ''

    for i = 1, peek_length do
      local v = code[from_where + i]

      if v == '\n' or (from_where + i) > code:len() then
        break
      end

      str = str..v
    end

    return str
  end
end

function PR:point_at(source, token)
  local tk_begin = token.pos - string.len(token.val)
  local left, right = shoot_left(source, tk_begin), shoot_right(source, token.pos)
  local str = left..token.val..right
  local pointer = string.rep('-', left:len())..'^'..string.rep('-', right:len() + token.val:len() - 1)

  return str..'\n'..pointer
end
