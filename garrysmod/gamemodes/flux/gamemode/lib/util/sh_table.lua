function table.Merge(dest, source)
  for k, v in pairs(source) do
    if istable(v) and istable(dest[k]) and k != 'class' then
      table.Merge(dest[k], v)
    else
      dest[k] = v
    end
  end

  return dest
end

function table.safe_merge(to, from)
  local old_idx_to, old_idx = to.__index, from.__index
  local references = {}

  to.__index = nil
  from.__index = nil

  for k, v in pairs(from) do
    if v == from or k == 'class' then
      references[k] = v
      from[k] = nil
    end
  end

  table.Merge(to, from)

  for k, v in pairs(references) do
    from[k] = v
  end

  to.__index = old_idx_to
  from.__index = old_idx

  return to
end

function table.map(t, c)
  local new_table = {}

  for k, v in pairs(t) do
    local val = c(v)
    if val != nil then
      table.insert(new_table, val)
    end
  end

  return new_table
end

function table.map_kv(t, c)
  local new_table = {}

  for k, v in pairs(t) do
    local val = c(k, v)
    if val != nil then
      table.insert(new_table, val)
    end
  end

  return new_table
end

function table.select(t, what)
  local new_table = {}

  for k, v in pairs(t) do
    if istable(v) then
      table.insert(new_table, v[what])
    end
  end

  return new_table
end

function table.slice(t, from, to)
  local new_table = {}
  for i = from, to do
    table.insert(new_table, t[i])
  end
  return new_table
end

function table.remove_functions(obj)
  if istable(obj) then
    for k, v in pairs(obj) do
      if isfunction(v) then
        obj[k] = nil
      elseif istable(v) then
        obj[k] = table.remove_functions(v)
      end
    end
  end

  return obj
end

function table.from_string(str)
  str = util.remove_newlines(str)

  local exploded = string.Explode(',', str)
  local tab = {}

  for k, v in ipairs(exploded) do
    if !isstring(v) then continue end

    if !string.find(v, '=') then
      v = v:trim_start(' ', true)

      if string.is_n(v) then
        v = tonumber(v)
      elseif string.find(v, '"') then
        v = v:trim_start('"'):trim_end('"')
      elseif v:find('{') then
        v = v:Replace('{', '')

        local last_key = nil
        local buff = v

        for k2, v2 in ipairs(exploded) do
          if k2 <= k then continue end

          if v2:find('}') then
            buff = buff..','..v2:Replace('}', '')

            last_key = k2

            break
          end

          buff = buff..','..v2
        end

        if last_key then
          for i = k, last_key do
            exploded[i] = nil
          end

          v = table.from_string(buff)
        end
      else
        v = v:trim_end('}')
      end

      v = v:trim_end('}')
      v = v:trim_end('\'')

      table.insert(tab, v)
    else
      local parts = string.Explode('=', v)
      local key = parts[1]:trim_end(' ', true):trim_end('\t', true)
      local value = parts[2]:trim_start(' ', true):trim_start('\t', true)

      if string.is_n(value) then
        value = tonumber(value)
      elseif value:find('{') and value:find('}') then
        value = table.from_string(value)
      else
        value = value:trim_end('}')
      end

      tab[key] = value
    end
  end

  return tab
end

do
  local table_meta = {
    __index = table
  }

  -- Special arrays.
  function a(initializer)
    return setmetatable(initializer, table_meta)
  end

  function is_a(obj)
    return getmetatable(obj) == table_meta
  end
end

-- For use with table#map
-- table.map(t, s'some_field')
function s(what)
  return function(tab)
    return tab[what]
  end
end

function w(str)
  return string.Split(str, ' ')
end

function wk(str)
  local ret = {}
  for k, v in ipairs(string.Split(str, ' ')) do
    ret[v] = true
  end
  return ret
end

-- A better implementation of PrintTable
function PrintTable(t, indent, done, indent_length)
  done = done or {}
  indent = indent or 0
  indent_length = indent_length or 1

  local keys = table.GetKeys(t)

  for k, v in pairs(keys) do
    local l = tostring(v):len()

    if l > indent_length then
      indent_length = l
    end
  end

  indent_length = indent_length + 1

  table.sort(keys, function(a, b)
    if isnumber(a) and isnumber(b) then return a < b end
    return tostring(a) < tostring(b)
  end)

  done[t] = true

  for i = 1, #keys do
    local key = keys[i]
    local value = t[key]
    Msg(string.rep('  ', indent))

    if istable(value) and !done[value] then
      local str_key = tostring(key)

      if value.class or value.class_name then
        Msg(str_key..':'..string.rep(' ', indent_length - str_key:len())..' #<'..tostring(value.class_name or key)..': '..tostring(value):gsub('table: ', '')..'>\n')
      elseif IsColor(value) then
        Msg(str_key..':'..string.rep(' ', indent_length - str_key:len())..' #<Color: '..value.r..' '..value.g..' '..value.b..' '..value.a..'>\n')
      elseif table.Count(value) == 0 then
        Msg(str_key..':'..string.rep(' ', indent_length - str_key:len())..' []\n')
      else
        done[value] = true
        Msg(str_key..':\n')
        PrintTable(value, indent + 1, done, indent_length - 3)
        done[value] = nil
      end
    else
      local str_key = tostring(key)
      Msg(str_key..string.rep(' ', indent_length - str_key:len())..'= ' )

      if isstring(value) then
        Msg('"'..value..'"\n')
      elseif isfunction(value) then
        Msg('function ('..tostring(value):gsub('function: ', '')..')\n')
      elseif istable(value) and (value.class or value.class_name) then
        Msg('#<'..tostring(value.class_name or key)..': '..tostring(value):gsub('table: ', '')..'>\n')
      else
        Msg(tostring(value)..'\n')
      end
    end
  end
end
