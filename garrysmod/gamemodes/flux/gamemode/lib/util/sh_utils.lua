function game.get_ammo_list()
  local last_ammo_name = game.GetAmmoName(1)
  local ammo_table = {last_ammo_name}

  while last_ammo_name != nil do
    last_ammo_name = game.GetAmmoName(table.insert(ammo_table, last_ammo_name))
  end

  return ammo_table
end

-- A function to check whether all of the arguments in vararg are valid (via IsValid).
function util.validate(...)
  local validate = {...}

  if #validate <= 0 then return false end

  for k, v in ipairs(validate) do
    if !IsValid(v) then
      return false
    end
  end

  return true
end

-- A function to do C-style formatted prints.
function printf(str, ...)
  print(Format(str, ...))
end

function util.to_b(value)
  return (tonumber(value) == 1 or value == true or value == 'true')
end

function util.wait_for_ent(entIndex, callback, delay, waitTime)
  local entity = Entity(entIndex)

  if !IsValid(entity) then
    local timerName = CurTime()..'_EntWait'

    timer.Create(timerName, delay or 0, waitTime or 100, function()
      local entity = Entity(entIndex)

      if IsValid(entity) then
        callback(entity)

        timer.Remove(timerName)
      end
    end)
  else
    callback(entity)
  end
end

function util.list_to_string(callback, separator, ...)
  if !isfunction(callback) then
    callback = function(obj) return tostring(obj) end
  end

  if !isstring(separator) then
    separator = ', '
  end

  local list = {...}
  local result = ''

  for k, v in ipairs(list) do
    local text = callback(v)

    if isstring(text) then
      result = result..text
    end

    if k < #list then
      result = result..separator
    end
  end

  return result
end

function util.player_list_to_string(player_list)
  local nlist = #player_list

  if nlist > 1 and nlist == #_player.GetAll() then
    return t'chat.everyone'
  end

  return util.list_to_string(function(obj) return (IsValid(obj) and obj:Name()) or 'Unknown Player' end, nil, unpack(player_list))
end

function util.remove_newlines(str)
  local exploded = string.Explode('', str)
  local to_ret = ''
  local skip = ''

  for k, v in ipairs(exploded) do
    if skip != '' then
      to_ret = to_ret..v

      if v == skip then
        skip = ''
      end

      continue
    end

    if v == '"' then
      skip = '"'

      to_ret = to_ret..v

      continue
    end

    if v == '\n' or v == '\t' then
      continue
    end

    to_ret = to_ret..v
  end

  return to_ret
end

function txt(text)
  local lines = string.Explode('\n', (text or ''):chomp('\n'))
  local lowest_indent
  local output = ''
  for k, v in ipairs(lines) do
    if v:match('^[%s]+$') then continue end
    local indent = v:match('^([%s]+)')
    if !indent then continue end
    if !lowest_indent then lowest_indent = indent end
    if indent:len() < lowest_indent:len() then
      lowest_indent = indent
    end
  end
  for k, v in ipairs(lines) do
    output = output..v:trim_start(lowest_indent)..'\n'
  end
  return output:chomp(' '):chomp('\n')
end

function get_player_name(player)
  return IsValid(player) and player:Name() or 'Console'
end

function util.vector_obstructed(vec1, vec2, filter)
  local trace = util.TraceLine({
    start = vec1,
    endpos = vec2,
    filter = filter
  })

  return trace.Hit
end
