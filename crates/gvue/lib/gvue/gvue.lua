mod 'Gvue'

--- Parses units and converts them into pixels.
function Gvue:parse_unit(u)
  if isnumber(u) then return u end
  if !isstring(u) then return 0 end
  if u:lower() == 'auto' then return 'auto' end

  local i, num = 0, nil
  local buf, cur = '', ''

  repeat
    cur = u[i]

    if !cur then
      if !num then
        return 0
      end

      return num, buf
    end

    if !buf:match('%d') and buf != '.' then
      num = tonumber(buf)
      buf = ''
    end

    buf = buf..cur

    i = i + 1
  until i < u:len()

  return 0
end
