--[[
RECOMMENDED VERSION

VERSION 1.4.1
Copyright thelastpenguin™

  You may use this for any purpose as long as:
  -  You don't remove this copyright notice.
  -  You don't claim this to be your own.
  -  You properly credit the author, thelastpenguin™, if you publish your work based on (and/or using) this.

  If you modify the code for any purpose, the above still applies to the modified code.

  The author is not held responsible for any damages incured from the use of pON, you use it at your own risk.

DATA TYPES SUPPORTED:
 - tables  -     k, v - pointers
 - strings -     k, v - pointers
 - numbers -    k, v
 - booleans-     k, v
 - Vectors -     k, v
 - Angles  -    k, v
 - Entities-     k, v
 - Players -     k, v

CHANGE LOG
V 1.1.0
 - Added Vehicle, NPC, NextBot, Player, Weapon
V 1.2.0
 - Added custom handling for k, v tables without any array component.
V 1.2.1
 - fixed deserialization bug.
V 1.3.0
 - added custom handling of strings without any escaped characters.
V 1.4.0
 - added detection of numbers without requiring 'n' datatype. (10 datatypes one for each num it could start with)
V 1.4.1
 - Various fixes and optimizarions, as well as merging stuff from the pON repo.

THANKS TO...
 - VERCAS for the inspiration.
]]

local pon = {}
_G.pon = pon

local type, count = type, table.Count
local tonumber = tonumber
local format = string.format

do
  local encode = {}
  local try_cache
  local cache_size = 0
  local type, count = type, table.Count
  local tonumber = tonumber
  local format = string.format

  --- Encodes a table. Tables and strings that were encoded before are written as
  -- pointers to their first occurrence.
  -- @param self [Map table of encoders]
  -- @param tbl [Map table to encode]
  -- @param output [List<String> pieces of the encoded string, appended to]
  -- @param cache [Map encoded tables and strings mapped to their pointer ids]
  encode['table'] = function(self, tbl, output, cache)

    if (cache[tbl]) then
      table.insert(output, '('..cache[tbl]..')')
      return
    else
      cache_size = cache_size + 1
      cache[tbl] = cache_size
    end
    -- CALCULATE COMPONENT SIZES
    local nSize = #tbl
    local kvSize = count(tbl) - nSize

    if (nSize == 0 and kvSize > 0) then
      table.insert(output, '[')
    else
      table.insert(output, '{')

      if nSize > 0 then
        for i = 1, nSize do
          local v = tbl[i]

          if v == nil then
            table.insert(output, '!')
            continue
          end

          local tv = type(v)
          -- HANDLE POINTERS
          if (tv == 'string') then
            local pid = cache[v]
            if (pid) then
              table.insert(output, '('..pid..')')
            else
              cache_size = cache_size + 1
              cache[v] = cache_size

              self.string(self, v, output, cache)
            end
          else
            self[tv](self, v, output, cache)
          end
        end
      end
    end

    if (kvSize > 0) then
      if (nSize > 0) then
        table.insert(output, '~')
      end
      for k, v in next, tbl do
        local key_type = type(k)
        if key_type != 'number' or k < 1 or k > nSize then
          local tk, tv = key_type, type(v)

          -- THE KEY
          if (tk == 'string') then
            local pid = cache[k]
            if (pid) then
              table.insert(output, '('..pid..')')
            else
              cache_size = cache_size + 1
              cache[k] = cache_size

              self.string(self, k, output, cache)
            end
          else
            self[tk](self, k, output, cache)
          end

          -- THE VALUE
          if (tv == 'string') then
            local pid = cache[v]
            if (pid) then
              table.insert(output, '('..pid..')')
            else
              cache_size = cache_size + 1
              cache[v] = cache_size

              self.string(self, v, output, cache)
            end
          else
            self[tv](self, v, output, cache)
          end

        end
      end
    end
    table.insert(output, '}')
  end

  -- ENCODE STRING
  local gsub = string.gsub
  --- Encodes a string, escaping semicolons if it contains any.
  -- @param self [Map table of encoders]
  -- @param str [String]
  -- @param output [List<String> pieces of the encoded string, appended to]
  encode['string'] = function(self, str, output)
    --if try_cache(str, output) then return end
    local estr, count = gsub(str, ";", "\\;")
    if (count == 0) then
      table.insert(output, '\''..str..';')
    else
      table.insert(output, '"'..estr..'";')
    end
  end

  -- ENCODE NUMBER

  --- Encodes a number.
  -- @param self [Map table of encoders]
  -- @param num [Number]
  -- @param output [List<String> pieces of the encoded string, appended to]
  encode['number'] = function(self, num, output)
    table.insert(output, tonumber(num)..';')
  end

  -- ENCODE BOOLEAN

  --- Encodes a boolean as 't' or 'f'.
  -- @param self [Map table of encoders]
  -- @param val [Boolean]
  -- @param output [List<String> pieces of the encoded string, appended to]
  encode['boolean'] = function(self, val, output)
    table.insert(output, val and 't' or 'f')
  end

  -- ENCODE VECTOR

  --- Encodes a vector as its three components.
  -- @param self [Map table of encoders]
  -- @param val [Vector]
  -- @param output [List<String> pieces of the encoded string, appended to]
  encode['Vector'] = function(self, val, output)
    table.insert(output, ('v'..val.x..','..val.y)..(','..val.z..';'))
  end

  -- ENCODE ANGLE

  --- Encodes an angle as its three components.
  -- @param self [Map table of encoders]
  -- @param val [Angle]
  -- @param output [List<String> pieces of the encoded string, appended to]
  encode['Angle'] = function(self, val, output)
    table.insert(output, ('a'..val.p..','..val.y)..(','..val.r..';'))
  end

  --- Encodes an entity as its entity index, or as '#' if it is not valid. Also used
  -- for players, vehicles, weapons, NPCs, NextBots and physics objects.
  -- @param self [Map table of encoders]
  -- @param val [Entity]
  -- @param output [List<String> pieces of the encoded string, appended to]
  encode['Entity'] = function(self, val, output)
    table.insert(output, 'E'..(IsValid(val) and val:EntIndex()..';' or '#'))
  end

  encode['Player']  = encode['Entity']
  encode['Vehicle'] = encode['Entity']
  encode['Weapon']  = encode['Entity']
  encode['NPC']     = encode['Entity']
  encode['NextBot'] = encode['Entity']
  encode['PhysObj'] = encode['Entity']

  --- Encodes nil as '?'.
  encode['nil'] = function()
    table.insert(output, '?')
  end

  --- Fallback for types that have no encoder. Reports the type and returns the encoder
  -- for nil.
  -- @param key [String name of the type]
  -- @return [Function encoder for nil]
  encode.__index = function(key)
    ErrorNoHalt('Cannot encode '..tostring(key)..', encoded as nil.')
    return encode['nil']
  end

  do
    local empty, concat = table.Empty, table.concat
    --- Serializes a table into a compact pON string. Supports nested tables, strings,
    -- numbers, booleans, vectors, angles and entities, both as keys and as values.
    -- ```
    -- local data = pon.encode({ name = 'Flux', origin = Vector(0, 0, 64) })
    -- local tbl = pon.decode(data)
    --
    -- print(tbl.name) -- Flux
    -- ```
    -- @param tbl [Map table to serialize]
    -- @return [String]
    -- @see [pon.decode]
    function pon.encode(tbl)
      local output = {}
      cache_size = 0
      encode['table'](encode, tbl, output, {})
      local res = concat(output)

      return res
    end
  end
end

do
  local tonumber = tonumber
  local find, sub, gsub, Explode = string.find, string.sub, string.gsub, string.Explode
  local Vector, Angle, Entity = Vector, Angle, Entity

  local decode = {}
  --- Decodes a table that has an array part, optionally followed by key-value pairs.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, Map decoded table]
  decode['{'] = function(self, index, str, cache)

    local cur = {}
    table.insert(cache, cur)

    local k, v, tk, tv = 1, nil, nil, nil
    while (true) do
      tv = sub(str, index, index)
      if (!tv or tv == '~') then
        index = index + 1
        break
      end
      if (tv == '}') then
        return index + 1, cur
      end

      -- READ THE VALUE
      index = index + 1
      index, v = self[tv](self, index, str, cache)
      cur[k] = v

      k = k + 1
    end

    while (true) do
      tk = sub(str, index, index)
      if (!tk or tk == '}') then
        index = index + 1
        break
      end

      -- READ THE KEY

      index = index + 1
      index, k = self[tk](self, index, str, cache)

      -- READ THE VALUE
      tv = sub(str, index, index)
      index = index + 1
      index, v = self[tv](self, index, str, cache)

      cur[k] = v
    end

    return index, cur
  end
  --- Decodes a table that consists of key-value pairs only.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, Map decoded table]
  decode['['] = function(self, index, str, cache)

    local cur = {}
    table.insert(cache, cur)

    local k, v, tk, tv = 1, nil, nil, nil
    while (true) do
      tk = sub(str, index, index)
      if (!tk or tk == '}') then
        index = index + 1
        break
      end

      -- READ THE KEY

      index = index + 1
      index, k = self[tk](self, index, str, cache)
      if !k then continue end

      -- READ THE VALUE
      tv = sub(str, index, index)
      index = index + 1
      if !self[tv] then
        print('did not find type: '..tv)
      end
      index, v = self[tv](self, index, str, cache)

      cur[k] = v
    end

    return index, cur
  end

  -- STRING

  --- Decodes a string that contains escaped semicolons.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, String decoded string]
  decode['"'] = function(self, index, str, cache)
    local finish = find(str, '";', index, true)
    local res = gsub(sub(str, index, finish - 1), '\\;', ';')
    index = finish + 2

    table.insert(cache, res)
    return index, res
  end
  -- STRING NO ESCAPING NEEDED

  --- Decodes a string that needed no escaping.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, String decoded string]
  decode['\''] = function(self, index, str, cache)
    local finish = find(str, ';', index, true)
    local res = sub(str, index, finish - 1)
    index = finish + 1

    table.insert(cache, res)
    return index, res
  end

  --- Decodes a nil value inside the array part of a table.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, Nil]
  decode['!'] = function(self, index, str, cache)
    return index, nil
  end

  -- NUMBER

  --- Decodes a number. Also registered for every digit and for '-', in which case the
  -- type character is the first character of the number.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, Number decoded number]
  decode['n'] = function(self, index, str, cache)
    index = index - 1
    local finish = find(str, ';', index, true)
    local num = tonumber(sub(str, index, finish - 1))
    index = finish + 1
    return index, num
  end

  decode['0'] = decode['n']
  decode['1'] = decode['n']
  decode['2'] = decode['n']
  decode['3'] = decode['n']
  decode['4'] = decode['n']
  decode['5'] = decode['n']
  decode['6'] = decode['n']
  decode['7'] = decode['n']
  decode['8'] = decode['n']
  decode['9'] = decode['n']
  decode['-'] = decode['n']

  -- POINTER

  --- Decodes a pointer to a table or string that was decoded earlier.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, Map/String value the pointer refers to]
  decode['('] = function(self, index, str, cache)
    local finish = find(str, ')', index, true)
    local num = tonumber(sub(str, index, finish - 1))
    index = finish + 1
    return index, cache[num]
  end

  -- BOOLEAN. ONE DATA TYPE FOR YES, ANOTHER FOR NO.

  --- Decodes the boolean true.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @return [Number position of the next value, Boolean true]
  decode['t'] = function(self, index)
    return index, true
  end

  --- Decodes the boolean false.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @return [Number position of the next value, Boolean false]
  decode['f'] = function(self, index)
    return index, false
  end

  -- VECTOR

  --- Decodes a vector.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, Vector decoded vector]
  decode['v'] = function(self, index, str, cache)
    local finish =  find(str, ';', index, true)
    local vecStr = sub(str, index, finish - 1)
    index = finish + 1; -- update the index.
    local segs = Explode(',', vecStr, false)
    return index, Vector(tonumber(segs[1]), tonumber(segs[2]), tonumber(segs[3]))
  end

  -- ANGLE

  --- Decodes an angle.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, Angle decoded angle]
  decode['a'] = function(self, index, str, cache)
    local finish =  find(str, ';', index, true)
    local angStr = sub(str, index, finish - 1)
    index = finish + 1; -- update the index.
    local segs = Explode(',', angStr, false)
    return index, Angle(tonumber(segs[1]), tonumber(segs[2]), tonumber(segs[3]))
  end

  -- ENTITY

  --- Decodes an entity from its entity index.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, Entity decoded entity, NULL if it was
  --   not valid when encoded]
  decode['E'] = function(self, index, str, cache)
    if (str[index] == '#') then
      index = index + 1
      return index, NULL
    else
      local finish = find(str, ';', index, true)
      local num = tonumber(sub(str, index, finish - 1))
      index = finish + 1
      return index, Entity(num)
    end
  end

  -- PLAYER

  --- Decodes a player from its entity index.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, Entity entity with that index, normally
  --   a player]
  decode['P'] = function(self, index, str, cache)
    local finish = find(str, ';', index, true)
    local num = tonumber(sub(str, index, finish - 1))
    index = finish + 1
    return index, Entity(num) or NULL
  end

  --- Decodes an explicit nil value.
  -- @param self [Map table of decoders]
  -- @param index [Number position in the string right after the type character]
  -- @param str [String encoded data]
  -- @param cache [List decoded tables and strings, used to resolve pointers]
  -- @return [Number position of the next value, Nil]
  decode['?'] = function(self, index, str, cache)
    return index + 1, nil
  end

  --- Restores a table from a string that was produced by pon.encode.
  -- @param data [String pON string]
  -- @return [Map]
  -- @see [pon.encode]
  function pon.decode(data)
    local _, res = decode[sub(data, 1, 1)](decode, 2, data, {})
    return res
  end
end
