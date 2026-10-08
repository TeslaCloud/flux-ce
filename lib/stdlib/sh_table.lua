--- Extensions of the `table` library and the shorthand helpers that go with it.
-- Adds functional helpers (`table.map`, `table.select`, `table.reduce`, `table.partition` and
-- others), filtering with `table.keep_if` and `table.delete_if`, comparison, conversion
-- between hashes and arrays, and serialization through SFS with a fallback to JSON. `a` turns
-- a table into an array that has the table library as its methods, `w` and `wk` build arrays
-- and hashes out of words, and `print_table` replaces PrintTable. `table.Merge` is replaced
-- with a version that leaves the `class` field of objects alone.
-- @module [table]

--- Recursively merges the source table into the destination table, overwriting existing keys.
-- Replaces the built-in table.Merge. Unlike the built-in, a table stored under the `class`
-- key is assigned by reference instead of being merged.
-- @param dest [Map table to merge into, modified in place]
-- @param source [Map table to take the values from]
-- @return [Map dest]
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

--- Merges a table into another one like table.Merge, but leaves `__index` of both tables
-- alone and skips the `class` key and any field of `from` that refers to `from` itself.
-- @param to [Map table to merge into, modified in place]
-- @param from [Map table to take the values from]
-- @return [Map to]
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

--- Creates an array out of the values a callback returns for every value of a table.
-- Values for which the callback returns nil are left out.
-- ```
-- local names = table.map(player.GetAll(), function(v) return v:name() end)
-- ```
-- @param t [Map/List table to go through]
-- @param c [Function callback(value), returns the value to store or nil to skip it]
-- @return [List values returned by the callback]
-- @see [s]
function table.map(t, c)
  local new_table = a{}

  for k, v in pairs(t) do
    local val = c(v)

    if val != nil then
      table.insert(new_table, val)
    end
  end

  return new_table
end

--- Creates an array out of the values a callback returns for every key-value pair of a table.
-- Pairs for which the callback returns nil are left out.
-- ```
-- local lines = table.map_kv({ a = 1, b = 2 }, function(k, v) return k..' = '..v end)
-- ```
-- @param t [Map/List table to go through]
-- @param c [Function callback(key, value), returns the value to store or nil to skip it]
-- @return [List values returned by the callback]
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

--- Filters the values of a table with a callback, or collects a single field from every
-- table inside of it.
-- ```
-- local alive = table.select(player.GetAll(), function(v, k) return v:Alive() end)
-- local names = table.select({ { name = 'a' }, { name = 'b' } }, 'name') -- { 'a', 'b' }
-- ```
-- @variant table.select(t, what)
--   @param t [Map/List table to filter]
--   @param what [Function callback(value, key), the value is kept unless it returns false]
-- @variant table.select(t, what)
--   @param t [Map/List table that consists of tables]
--   @param what [String/Number key to read from every value that is a table]
-- @return [List selected values]
function table.select(t, what)
  local new_table = a{}

  if isfunction(what) then
    for k, v in pairs(t) do
      if what(v, k) != false then
        table.insert(new_table, v)
      end
    end
  else
    for k, v in pairs(t) do
      if istable(v) then
        table.insert(new_table, v[what])
      end
    end
  end

  return new_table
end

--- Returns the part of an array between two indexes, both inclusive.
-- @param t [List]
-- @param from [Number first index]
-- @param to [Number last index]
-- @return [List the elements between from and to]
function table.slice(t, from, to)
  local new_table = a{}

  for i = from, to do
    table.insert(new_table, t[i])
  end

  return new_table
end

--- Removes all functions from a table and from the tables nested in it. Modifies the table.
-- @param obj [Any table to clean up, anything else is returned as-is]
-- @return [Any the same object]
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

do
  local ops = {
    ['+']  = function(a, b) return a + b end,
    ['-']  = function(a, b) return a - b end,
    ['*']  = function(a, b) return a * b end,
    ['/']  = function(a, b) return a / b end,
    ['**'] = function(a, b) return a ^ b end,
    ['^']  = function(a, b) return a ^ b end,
    ['%']  = function(a, b) return a % b end
  }

  --- Combines all elements of an array into a single value, by applying an operator to the
  -- running result and each element in order. The running result starts at 0.
  -- ```
  -- table.reduce({ 1, 2, 3 }, '+') -- 6
  -- table.reduce({ 1, 5, 3 }, function(result, v) return math.max(result, v) end) -- 5
  -- ```
  -- @param tab [List]
  -- @param op [String/Function one of '+', '-', '*', '/', '**', '^' and '%', or a
  --   callback(result, value) that returns the new result]
  -- @return [Any the final result, a Number for the built-in operators]
  function table.reduce(tab, op)
    local sum = 0

    if !isfunction(op) then
      op = ops[op]
    end

    for k, v in ipairs(tab) do
      sum = op(sum, v)
    end

    return sum
  end
end

--- Adds up all elements of an array.
-- @param tab [List<Number>]
-- @return [Number the sum, 0 for an empty array]
function table.sum(tab)
  return table.reduce(tab, '+')
end

--- Flattens the tables nested inside of a table into a single array.
-- Tables that have a `class` field (objects) are treated as values.
-- @param tab [Map/List]
-- @return [List the flattened values]
function table.flatten(tab)
  local t = a{}

  for k, v in pairs(tab) do
    if istable(v) and !v.class then
      table.insert(t, table.flatten(tab))
    else
      table.insert(t, v)
    end
  end

  return v
end

--- Returns a copy of the table without duplicate values.
-- The values keep their original keys, so the copy of an array can have gaps in it.
-- @param tab [Map/List]
-- @param condition=nil [Function callback(value) that returns true for the values to leave out,
--   used instead of the duplicate check]
-- @return [Map/List table of unique values]
function table.uniq(tab, condition)
  local t = a{}
  local vals = {}

  condition = condition or function(v) return vals[v] end

  for k, v in pairs(tab) do
    if !condition(v) then
      t[k] = v
      vals[v] = true
    end
  end

  return t
end

do
  local function run_comp(key, value, t2)
    if !istable(value) then
      if value != t2[key] then
        return false
      end
    else
      if !table.equal(value, t2[key]) then
        return false
      end
    end

    return true
  end

  --- Checks whether two tables have the same contents. Nested tables are compared recursively.
  -- @param tab1 [Map/List]
  -- @param tab2 [Map/List]
  -- @return [Boolean true if the contents are equal, false if not or if either one is not a table]
  function table.equal(tab1, tab2)
    if !istable(tab1) or !istable(tab2) then return false end
    if tab1 == tab2 then return true end

    local t1, t2 = 0, 0

    for k, v in pairs(tab1) do
      t1 = t1 + 1

      if !run_comp(k, v, tab2) then
        return false
      end
    end

    for k, v in pairs(tab2) do
      t2 = t2 + 1

      if !run_comp(k, v, tab1) then
        return false
      end
    end

    if t1 != t2 then return false end

    return true
  end
end

--- Returns the memory address of a table, which identifies it uniquely while it exists.
-- @param tab [Map/List]
-- @return [String the address without the 'table: 0x' prefix, Number 1 if the prefix was removed]
function table.hash(tab)
  return tostring(tab):gsub('table: 0x', '')
end

--- Concatenates all values of a table into a single string, including those of nested tables.
-- @param tab [Map/List]
-- @param sep='' [String separator; it is not put between the values by the current code]
-- @return [String the concatenated values]
function table.join(tab, sep)
  local str = ''
  sep = sep or ''

  for k, v in pairs(tab) do
    if !istable(v) then
      str = str..tostring(v)
    else
      str = str..table.join(v, sep)
    end
  end

  return str
end

--- Returns a copy of the table without the entries for which the callback returns true.
-- The entries keep their keys and the original table is not modified.
-- @param tab [Map/List]
-- @param callback [Function callback(key, value), returns true to leave the entry out]
-- @return [Map/List the filtered copy]
-- @see [table.delete]
function table.delete_if(tab, callback)
  local new_tab = a{}

  for k, v in pairs(tab) do
    if callback(k, v) != true then
      new_tab[k] = v
    end
  end

  return new_tab
end

--- Removes the entries for which the callback returns true from the table itself.
-- @param tab [Map/List table to modify]
-- @param callback [Function callback(key, value), returns true to remove the entry]
-- @return [Map/List the same table]
-- @see [table.delete_if]
function table.delete(tab, callback)
  for k, v in pairs(tab) do
    if callback(k, v) == true then
      tab[k] = nil
    end
  end

  return tab
end

--- Returns a copy of the table that only has the entries for which the callback returns true.
-- The entries keep their keys and the original table is not modified.
-- @param tab [Map/List]
-- @param callback [Function callback(key, value), returns true to keep the entry]
-- @return [Map/List the filtered copy]
-- @see [table.keep]
function table.keep_if(tab, callback)
  local new_tab = a{}

  for k, v in pairs(tab) do
    if callback(k, v) == true then
      new_tab[k] = v
    end
  end

  return new_tab
end

--- Removes the entries for which the callback does not return true from the table itself.
-- @param tab [Map/List table to modify]
-- @param callback [Function callback(key, value), returns true to keep the entry]
-- @return [Map/List the same table]
-- @see [table.keep_if]
function table.keep(tab, callback)
  for k, v in pairs(tab) do
    if callback(k, v) != true then
      tab[k] = nil
    end
  end

  return tab
end

--- Returns the first element of an array.
-- @param tab [List]
-- @return [Any the first element, or nil if the array is empty]
function table.first(tab)
  return tab[1]
end

--- Returns the last element of an array.
-- @param tab [List]
-- @return [Any the last element, or nil if the array is empty]
function table.last(tab)
  return tab[#tab]
end

--- Checks whether the callback returns a truthy value for exactly one entry of the table.
-- @param tab [Map/List]
-- @param callback [Function callback(key, value)]
-- @return [Boolean]
function table.one(tab, callback)
  local hit = false

  for k, v in pairs(tab) do
    if callback(k, v) then
      if !hit then
        hit = true
      else
        return false
      end
    end
  end

  return hit
end

--- Checks whether the callback returns a truthy value for none of the entries of the table.
-- @param tab [Map/List]
-- @param callback [Function callback(key, value)]
-- @return [Boolean]
function table.none(tab, callback)
  for k, v in pairs(tab) do
    if callback(k, v) then
      return false
    end
  end

  return true
end

--- Splits the values of a table into two arrays: those for which the callback returns a truthy
-- value and all the others.
-- ```
-- local admins, others = table.partition(player.GetAll(), function(k, v) return v:IsAdmin() end)
-- ```
-- @param tab [Map/List]
-- @param callback [Function callback(key, value)]
-- @return [List values the callback accepted, List values it did not]
function table.partition(tab, callback)
  local t1, t2 = a{}, a{}

  for k, v in pairs(tab) do
    if callback(k, v) then
      table.insert(t1, v)
    else
      table.insert(t2, v)
    end
  end

  return t1, t2
end

--- Converts a hash into an array of { key, value } pairs.
-- ```
-- table.to_array({ a = 1, b = 2 }) -- { { 'a', 1 }, { 'b', 2 } }, in no particular order
-- ```
-- @param tab [Map]
-- @return [List<List> key-value pairs]
-- @see [table.to_hash]
function table.to_array(tab)
  local a = a{}

  for k, v in pairs(tab) do
    table.insert(a, { k, v })
  end

  return a
end

--- Converts an array of { key, value } pairs into a hash.
-- ```
-- table.to_hash({ { 'a', 1 }, { 'b', 2 } }) -- { a = 1, b = 2 }
-- ```
-- @param tab [List<List> key-value pairs]
-- @return [Map]
-- @see [table.to_array]
function table.to_hash(tab)
  local h = a{}

  for k, v in ipairs(tab) do
    if istable(v) then
      h[v[1]] = v[2]
    else
      table.insert(v)
    end
  end

  return h
end

--- Converts a table into the string format.
-- @param tab [Map/List table to convert]
-- @return [String hex-encoded SFS data, JSON if SFS fails, or an empty string if both fail or
--   tab is not a table]
function table.serialize(tab)
  if istable(tab) then
    local success, value, err = pcall(sfs.encode_to_hex, tab)

    if !success or err then
      success, value = pcall(util.TableToJSON, tab)

      if !success then
        ErrorNoHalt('Failed to serialize a table!\n')
        error_with_traceback(value)

        return ''
      end
    end

    return value
  else
    print('You must serialize a table, not '..type(tab)..'!')
    return ''
  end
end

--- Converts a string back into a table. Uses SFS at first, if it fails it falls back to JSON.
-- @param data [String string to convert]
-- @return [Map decoded table; an empty table if data is not a string, nil if it is neither
--   valid SFS nor valid JSON]
function table.deserialize(data)
  if isstring(data) then
    local success, value, err = pcall(sfs.decode_from_hex, data)

    if !success or err then
      success, value = pcall(util.JSONToTable, data)

      if !success then
        ErrorNoHalt('Failed to deserialize a string!\n')
        error_with_traceback(value)

        return {}
      end
    end

    return value
  else
    print('You must deserialize a string, not '..type(data)..'!')
    return {}
  end
end

do
  local table_meta = {
    __index = table
  }

  --- Turns a table into a special array that has the functions of the table library as methods.
  -- The table itself is modified and returned.
  -- ```
  -- local words = a{ 'one', 'two' }
  -- words:insert('three')
  -- local lengths = words:map(function(v) return v:len() end) -- { 3, 3, 5 }
  -- ```
  -- @param initializer [Map/List table to turn into a special array]
  -- @return [List the same table]
  function a(initializer)
    return setmetatable(initializer, table_meta)
  end

  --- Checks whether an object is a special array created with `a`.
  -- @param obj [Any]
  -- @return [Boolean]
  -- @see [a]
  function is_a(obj)
    return getmetatable(obj) == table_meta
  end
end

--- Creates a function that returns the given field of the table passed to it.
-- For use with table#map.
-- ```
-- table.map(t, s'some_field')
-- ```
-- @param what [String/Number key of the field]
-- @return [Function accessor(tab), returns tab[what]]
function s(what)
  return function(tab)
    return tab[what]
  end
end

--- Splits a string of words into an array. Words are separated by spaces or newlines.
-- ```
-- w'data ammo equipment' -- { 'data', 'ammo', 'equipment' }
-- ```
-- @param str [String space-separated words]
-- @return [List<String> words]
function w(str)
  return str:gsub('\n', ' '):gsub('  ', ' '):split(' ')
end

--- Splits a string of space-separated words into a hash that has the words as its keys.
-- ```
-- wk'data ammo equipment' -- { data = true, ammo = true, equipment = true }
-- ```
-- @param str [String space-separated words]
-- @return [Map word => true]
function wk(str)
  local ret = {}

  for k, v in ipairs(str:split(' ')) do
    ret[v] = true
  end

  return ret
end

--- Creates an array of consecutive integers.
-- @param from [Number first number]
-- @param to [Number last number, inclusive]
-- @return [List<Number>]
function table.range(from, to)
  local t = {}

  for i = from, to do
    table.insert(t, i)
  end

  return t
end

--- Prints the contents of a table to the console, sorted by key, with nested tables indented.
-- A better implementation of PrintTable, which it also replaces.
-- @param t [Map/List table to print]
-- @param indent=0 [Number indentation level to print at]
-- @param done={} [Map tables that are being printed already, to avoid endless recursion]
-- @param indent_length=1 [Number minimum width of the key column]
function print_table(t, indent, done, indent_length)
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
        Msg(
          str_key..':'..
          string.rep(' ', indent_length - str_key:len())..
          ' #<'..tostring(value.class_name or key)..': '..
          tostring(value):gsub('table: ', '')..'>\n'
        )
      elseif IsColor(value) then
        Msg(str_key..':'..
        string.rep(' ', indent_length - str_key:len())..
        ' #<Color: '..value.r..' '..value.g..' '..value.b..' '..value.a..'>\n'
      )
      elseif table.IsEmpty(value) then
        Msg(str_key..':'..string.rep(' ', indent_length - str_key:len())..' []\n')
      else
        done[value] = true
        Msg(str_key..':\n')
        print_table(value, indent + 1, done, indent_length - 3)
        done[value] = nil
      end
    else
      local str_key = tostring(key)
      Msg(str_key..string.rep(' ', indent_length - str_key:len())..'= ')

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

PrintTable = print_table
