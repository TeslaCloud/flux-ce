--- Returns the names of all ammo types that are registered in the game.
-- @return [List<String> ammo type names]
function game.get_ammo_list()
  local last_ammo_name = game.GetAmmoName(1)
  local ammo_table = { last_ammo_name }

  while last_ammo_name != nil do
    last_ammo_name = game.GetAmmoName(table.insert(ammo_table, last_ammo_name))
  end

  return ammo_table
end

--- Checks whether all of the arguments in vararg are valid (via IsValid).
-- @param ... [Vararg objects to check]
-- @return [Boolean true if all of them are valid, false if any is not or if there are none]
function util.validate(...)
  local validate = { ... }

  if #validate <= 0 then return false end

  for k, v in ipairs(validate) do
    if !IsValid(v) then
      return false
    end
  end

  return true
end

--- Prints C-style formatted strings.
-- @param str [String format string, see string.format]
-- @param ... [Vararg values to put into the format string]
function printf(str, ...)
  print(Format(str, ...))
end

--- Converts a value to a boolean. Only true, 'true', 1 and '1' count as true.
-- @param value [Any]
-- @return [Boolean]
function util.to_b(value)
  return (tonumber(value) == 1 or value == true or value == 'true')
end

--- Calls the callback as soon as the entity with the given index becomes valid, right away if it
-- already is. Useful on the client, where an entity index can arrive before the entity
-- itself does. Gives up without calling the callback once it runs out of attempts.
-- ```
-- util.wait_for_ent(ply_index, function(player)
--   hook.run('PlayerModelChanged', player, new_model, old_model)
-- end)
-- ```
-- @param ent_index [Number entity index]
-- @param callback [Function callback(entity), receives the valid Entity]
-- @param delay=0 [Number seconds between the attempts]
-- @param wait_time=100 [Number maximum amount of attempts]
function util.wait_for_ent(ent_index, callback, delay, wait_time)
  local entity = Entity(ent_index)

  if !IsValid(entity) then
    local timer_name = CurTime()..'_ent_wait'

    timer.Create(timer_name, delay or 0, wait_time or 100, function()
      local entity = Entity(ent_index)

      if IsValid(entity) then
        callback(entity)

        timer.Remove(timer_name)
      end
    end)
  else
    callback(entity)
  end
end

--- Joins the text representations of a list of objects into a single string.
-- ```
-- util.list_to_string(nil, nil, 1, 2, 3) -- '1, 2, 3'
-- util.list_to_string(function(obj) return obj:name() end, ' and ', player1, player2)
-- ```
-- @param callback=tostring [Function callback(object), returns the String to use for the object]
-- @param separator=', ' [String text to put between the objects]
-- @param ... [Vararg objects to list]
-- @return [String the joined list]
function util.list_to_string(callback, separator, ...)
  if !isfunction(callback) then
    callback = function(obj) return tostring(obj) end
  end

  if !isstring(separator) then
    separator = ', '
  end

  local list = { ... }
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

--- Joins the names of a list of players into a single comma-separated string.
-- If the list consists of all players on the server (and there are at least two), returns
-- the 'ui.chat.everyone' phrase instead.
-- @param player_list [List<Player>]
-- @return [String player names, or the 'ui.chat.everyone' phrase]
function util.player_list_to_string(player_list)
  local nlist = #player_list

  if nlist > 1 and nlist == #_player.all() then
    return 'ui.chat.everyone'
  end

  return util.list_to_string(function(obj)
    return (IsValid(obj) and obj:name()) or 'Unknown Player'
  end, nil, unpack(player_list))
end

--- Removes the newlines and tabs from a string, except for those inside of double quotes.
-- @param str [String]
-- @return [String]
function util.remove_newlines(str)
  local pieces = str:split()
  local to_ret = ''
  local skip = ''

  for k, v in ipairs(pieces) do
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

--- Removes the common indentation and the surrounding blank lines from a multi-line string,
-- so that long texts can be indented together with the code around them.
-- ```
-- print(txt[[
--   Usage:
--     flux help
-- ]])
-- -- Usage:
-- --   flux help
-- ```
-- @param text [String multi-line text]
-- @return [String the text without the common indentation]
function txt(text)
  local lines = (text or ''):chomp('\n'):split('\n')
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

--- Returns the Steam name of a player, or the translated name of the console if the player is
-- not valid (as it is for commands that are run from the server console).
-- @param player [Player player, or an invalid entity or nil for the console]
-- @return [String]
function get_player_name(player)
  return IsValid(player) and player:steam_name() or t'notification.console'
end

--- Checks whether anything is in the way between two positions, using a line trace.
-- @param vec1 [Vector start position]
-- @param vec2 [Vector end position]
-- @param filter=nil [Entity/List<Entity>/Function entities for the trace to ignore, same as
--   the filter of util.TraceLine]
-- @return [Boolean true if the trace hit something]
function util.vector_obstructed(vec1, vec2, filter)
  local trace = util.TraceLine({
    start = vec1,
    endpos = vec2,
    filter = filter
  })

  return trace.Hit
end

--- Checks whether a door is currently open.
-- @param entity [Entity]
-- @return [Boolean true if the door is open, false if it is closed or the entity is not a door]
function util.door_is_opened(entity)
  if entity:is_door() then
    local data = entity:GetSaveTable()

    if data.m_toggle_state then
      return data.m_toggle_state == 0
    elseif data.m_eDoorState then
      return data.m_eDoorState != 0
    end
  end

  return false
end

local operators = {
  equal = function(a, b)
    return a == b
  end,
  unequal = function(a, b)
    return a != b
  end,
  less = function(a, b)
    return a < b
  end,
  greater = function(a, b)
    return a > b
  end,
  less_equal = function(a, b)
    return a <= b
  end,
  greater_equal = function(a, b)
    return a >= b
  end,
  ['and'] = function(a, b)
    return a and b
  end,
  ['or'] = function(a, b)
    return a or b
  end,
  ['not'] = function(a, b)
    return !a
  end
}

local operators_symbol = {
  less = '<',
  greater = '>',
  less_equal = '<=',
  greater_equal = '>=',
  equal = '==',
  unequal = '!=',
  ['and'] = '&&',
  ['or'] = '||',
  ['not'] = '!'
}

--- Applies an operator to two values by the name of the operator.
-- ```
-- util.process_operator('greater_equal', 5, 3) -- true
-- ```
-- @param op [String operator name: 'equal', 'unequal', 'less', 'greater', 'less_equal',
--   'greater_equal', 'and', 'or' or 'not']
-- @param a [Any left operand]
-- @param b [Any right operand, not used by 'not']
-- @return [Any result of the operation, a Boolean for the comparisons and 'not']
-- @see [util.get_operators]
function util.process_operator(op, a, b)
  return operators[op](a, b)
end

--- Returns the names of all operators that util.process_operator supports.
-- @return [List<String> operator names]
function util.get_operators()
  local list = {}

  for k, v in pairs(operators) do
    table.insert(list, k)
  end

  return list
end

--- Returns the equality and logical operators together with their symbols.
-- @return [Map operator name => String symbol, such as unequal => '!=']
function util.get_logical_operators()
  local list = {
    equal = '==',
    unequal = '!=',
    ['and'] = '&&',
    ['or'] = '||',
    ['not'] = '!'
  }

  return list
end

--- Returns the comparison operators together with their symbols.
-- @return [Map operator name => String symbol, such as less_equal => '<=']
function util.get_relational_operators()
  local list = {
    less = '<',
    greater = '>',
    less_equal = '<=',
    greater_equal = '>=',
    equal = '==',
    unequal = '!='
  }

  return list
end

--- Returns the equality operators together with their symbols.
-- @return [Map operator name => String symbol, such as equal => '==']
function util.get_equal_operators()
  local list = {
    equal = '==',
    unequal = '!='
  }

  return list
end

--- Returns the symbol of an operator, such as '>=' for 'greater_equal'.
-- @param op [String operator name]
-- @return [String symbol, or nil if there is no such operator]
function util.operator_to_symbol(op)
  return operators_symbol[op]
end

--- Similar to the <=> operator in other languages.
-- @param a [Number/String left value]
-- @param b [Number/String right value, has to be comparable with a]
-- @return [Number -1 if a < b; 0 if a == b; and 1 if a > b]
function compare(a, b)
  if a > b then  return 1 end
  if a == b then return 0 end
  return -1
end

--- Print a traceback to the current function call.
-- @param suppress=false [Boolean do not print the traceback, only return it]
-- @param ... [Vararg arguments for debug.traceback, such as a message and a level]
-- @return [List string pieces of the traceback]
function print_traceback(suppress, ...)
  local trace_text = debug.traceback(...)

  trace_text = trace_text
                 :gsub('stack traceback:\n', '\n')
                 :gsub(': in main chunk', '')
                 :gsub(': in function', ': in')
                 :gsub('\n%s+', '\n')
                 :gsub('^\n', '')

  local pieces = trace_text:split('\n')
  pieces[1] = '' -- remove the actual call to debug.traceback

  if !suppress then
    for k, v in ipairs(pieces) do
      if v and v != '' then
        Msg('    ')
        MsgC(Color(0, 255, 255), 'from '..v)
        Msg('\n')
      end
    end
  end

  return pieces
end

--- Prints an error using ErrorNoHalt but without the character limit.
-- @param ... [Vararg strings that are concatenated into the error message]
-- @see [ErrorNoHalt]
function long_error(...)
  local text = table.concat({...})
  local len = string.len(text)
  local pieces = {}

  if len > 200 then
    for i = 1, len / 200 do
      table.insert(pieces, text:sub((i - 1) * 200 + 1, math.min(i * 200, len)))
    end
  else
    pieces = { text }
  end

  for k, v in ipairs(pieces) do
    ErrorNoHalt(v)
  end

  if text:ends('\n') then
    print ''
  end
end

--- Print an error message followed by a complete stack traceback.
-- Unlike error, this does not stop the execution of the calling code.
-- @param msg [String error message]
function error_with_traceback(msg)
  long_error(msg..'\n')
  print_traceback()
end

local env = table.Copy(_G)
local unsafe = w[[debug require setfenv getfenv File _G _R RunString 
                 CompileString rawget rawset rawequal setmetatable
                 coroutine module package newproxy]]

for k, v in ipairs(unsafe) do
  env[v] = nil
end

env['string']['dump'] = nil

--- Runs a Lua file in a restricted environment that has no access to unsafe globals such as
-- debug, require, RunString, CompileString, setmetatable or File.
-- The environment is a copy of the globals made when the standard library was loaded.
-- @param f [String file path relative to the lua/ folder]
-- @return [Vararg whatever the file returns]
function include_sandboxed(f)
  local c = CompileString(file.Read(f, 'LUA'), f)
  debug.setfenv(c, env)
  return c()
end

do
  local enumerators = {}

  --- Creates enumerator variables based on a provided list.
  -- Starts at 0.
  -- ```
  -- --         0           1             2
  -- enumerate 'GENDER_MALE GENDER_FEMALE GENDER_OTHER'
  -- ```
  -- @param enums [String space-separated enumerator names]
  -- @param existing_enumerator=nil [String prefix of an earlier group (such as 'GENDER') to
  --   continue the numbering of, starting right after the highest enumerator of that group]
  -- @return [Number highest enumerator, or nil if enums is not a string or is empty]
  function enumerate(enums, existing_enumerator)
    if !isstring(enums) or enums:len() == 0 then return end

    local words = enums:upper():gsub('\n', ' '):split ' '
    local first_valid_word = nil
    local enumerator = 0

    if existing_enumerator then
      enumerator = (enumerators[existing_enumerator] or -1) + 1
    end

    for _, word in ipairs(words) do
      if word != '' and word != ' ' then
        if !first_valid_word then
          first_valid_word = word
        end

        _G[word] = enumerator
        enumerator = enumerator + 1
      end
    end

    if enumerator > 0 then
      local idx = first_valid_word:match('^([%w0-9]+)')

      if idx then
        enumerators[idx] = enumerator - 1
      end
    end

    return enumerator - 1
  end
end
