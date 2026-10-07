local String = {
  lower = function(...)
    return (string.utf8lower or string.lower)(...)
  end,
  upper = function(...)
    return (string.utf8upper or string.upper)(...)
  end,
  sub = function(...)
    return (string.utf8sub or string.sub)(...)
  end
}

local string_meta = getmetatable('')

-- Ruby-style names for the built-in string functions.
string.basename                        = string.GetFileFromFilename
string.chars                           = string.ToTable
string.comma                           = string.Comma
string.dirname                         = string.GetPathFromFilename
string.end_with                        = string.EndsWith
string.explode                         = string.Explode
string.extname                         = string.GetExtensionFromFilename
string.first                           = string.Left
string.formatted_time                  = string.FormattedTime
string.from_color                      = string.FromColor
string.get_char                        = string.GetChar
string.implode                         = string.Implode
string.javascript_safe                 = string.JavascriptSafe
string.last                            = string.Right
string.lstrip                          = string.TrimLeft
string.nice_size                       = string.NiceSize
string.nice_time                       = string.NiceTime
string.pattern_safe                    = string.PatternSafe
string.replace                         = string.Replace
string.rstrip                          = string.TrimRight
string.set_char                        = string.SetChar
string.start_with                      = string.StartWith
string.strip                           = string.Trim
string.strip_extension                 = string.StripExtension
string.to_color                        = string.ToColor
string.to_minutes_seconds              = string.ToMinutesSeconds
string.to_minutes_seconds_milliseconds = string.ToMinutesSecondsMilliseconds

--- Splits a string into pieces around a separator.
-- Splits the string into individual characters if no separator is given.
-- @param str [String string to split]
-- @param sep='' [String separator]
-- @return [List<String> pieces]
function string.split(str, sep)
  sep = sep or ''
  return string.Split(str, sep)
end

do
  local vowels = {
    ['a'] = true,
    ['e'] = true,
    ['o'] = true,
    ['i'] = true,
    ['u'] = true
  }

  --- Checks whether the character is a vowel or not.
  -- On the client the current language can override the result with its `is_vowel` function.
  -- @param char [String single character]
  -- @return [Boolean true if it is a vowel, nil (or the language's own answer) otherwise]
  function string.vowel(char)
    char = String.lower(char)

    if CLIENT then
      local lang = Flux.Lang:GetTable(GetConVar('gmod_language'):GetString())

      if lang and isfunction(lang.is_vowel) then
        local override = lang:is_vowel(char)

        if override != nil then
          return override
        end
      end
    end

    return vowels[char]
  end
end

--- Removes a substring from the end of the string.
-- @param str [String the string to trim]
-- @param needle [String substring to remove]
-- @param all_occurrences=false [Boolean keep removing while the string still ends with needle]
-- @return [String the trimmed string]
function string.trim_end(str, needle, all_occurrences)
  if !needle or needle == '' then
    return str
  end

  if str:end_with(needle) then
    if all_occurrences then
      while str:end_with(needle) do
        str = str:trim_end(needle)
      end

      return str
    end

    return String.sub(str, 1, utf8.len(str) - utf8.len(needle))
  else
    return str
  end
end

--- Removes a substring from the beginning of the string.
-- @param str [String the string to trim]
-- @param needle [String substring to remove]
-- @param all_occurrences=false [Boolean keep removing while the string still starts with needle]
-- @return [String the trimmed string]
function string.trim_start(str, needle, all_occurrences)
  if !needle or needle == '' then
    return str
  end

  if str:start_with(needle) then
    if all_occurrences then
      while str:start_with(needle) do
        str = str:trim_start(needle)
      end

      return str
    end

    return String.sub(str, utf8.len(needle) + 1, utf8.len(str))
  else
    return str
  end
end

--- Checks whether the string is full uppercase or not.
-- @param str [String]
-- @return [Boolean]
function string.is_upper(str)
  return String.upper(str) == str
end

--- Checks whether the string is full lowercase or not.
-- @param str [String]
-- @return [Boolean]
function string.is_lower(str)
  return String.lower(str) == str
end

--- Finds all occurrences of a pattern in a string.
-- ```
-- local hits = string.find_all('{data:rank} {callback:get_name}', '{([%w_]+):([%w_]+)}')
-- -- hits[1] = { text = '{data:rank}', start_pos = 1, end_pos = 11, matches = { 'data', 'rank' } }
-- ```
-- @param str [String string to search in]
-- @param pattern [String Lua pattern to search for]
-- @return [List<Map> a hash with the text, start_pos, end_pos and matches (captures) keys
--   for every occurrence, or nil if str or pattern is missing]
function string.find_all(str, pattern)
  if !str or !pattern then return end

  local hits = {}
  local last_pos = 1

  while true do
    local find_data = { string.find(str, pattern, last_pos) }
    local start_pos, end_pos = find_data[1], find_data[2]

    if !start_pos then
      break
    end

    table.insert(hits, {
      text      = String.sub(str, start_pos, end_pos),
      start_pos = start_pos,
      end_pos   = end_pos,
      matches   = table.map(find_data, function(v) if isstring(v) then return v end end)
    })

    last_pos = end_pos + 1
  end

  return hits
end

--- Checks whether the string contains a substring.
-- The substring is searched for as plain text, not as a pattern.
-- @param str [String string to search in]
-- @param substring [String text to search for]
-- @param start_pos=1 [Number position to start searching from]
-- @return [Number start position of the substring or nil if it was not found, Number end position]
function string.include(str, substring, start_pos)
  return string.find(str, substring, start_pos, true)
end

--- Checks if the string is a command or not, i.e. whether it starts with one of the configured
-- command prefixes. The StringIsCommand hook can return false to prevent that.
-- @param str [String]
-- @return [Boolean whether the string is a command, Number length of the prefix if it is one]
function string.is_command(str)
  local prefixes = Config.get('command_prefixes') or {}

  for k, v in ipairs(prefixes) do
    if str:start_with(v) and hook.Run('StringIsCommand', str) != false then
      return true, utf8.len(v)
    end
  end

  return false
end

do
  -- IDs should not have any of those characters.
  local blocked_chars = {
    "'", '"', '\\', '/', '^',
    ':', '.', ';', '&', ',', '%'
  }

  --- Converts a string to an ID: lowercases it, replaces spaces with underscores and removes
  -- the characters that IDs must not have (quotes, slashes and most punctuation).
  -- @param str [String]
  -- @return [String the ID]
  function string.to_id(str)
    str = String.lower(str)
    str = str:gsub(' ', '_')

    for k, v in ipairs(blocked_chars) do
      str = str:replace(v, '')
    end

    return str
  end
end

--- Appends the ending to the string, unless the string already ends with it.
-- @param str [String]
-- @param ending [String]
-- @return [String string that ends with the ending]
function string.ensure_end(str, ending)
  if str:end_with(ending) then return str end
  return str..ending
end

--- Prepends the start to the string, unless the string already starts with it.
-- @param str [String]
-- @param start [String]
-- @return [String string that starts with the start]
function string.ensure_start(str, start)
  if str:start_with(start) then return str end
  return start..str
end

--- Indents every line of the string. Lines that would only consist of whitespace are left empty.
-- @param str [String]
-- @param indent [String text to put in front of every line, such as a few spaces]
-- @return [String the indented string]
function string.set_indent(str, indent)
  return indent..str:gsub('\n', '\n'..indent):gsub('\n%s+\n', '\n\n')
end

--- Makes the `+` operator concatenate strings.
-- Strings that can be converted to numbers are still added up as numbers by Lua itself.
-- @param right [Any right-hand operand, converted with tostring]
-- @return [String the concatenated string]
function string_meta:__add(right)
  return self..tostring(right)
end

--- Checks whether the string can be converted to a number.
-- @param char [String]
-- @return [Boolean]
function string.is_n(char)
  return tonumber(char) != nil
end

--- Counts how many times a character occurs in the string.
-- @param str [String]
-- @param char [String single character]
-- @return [Number amount of occurrences]
function string.count(str, char)
  local hits = 0

  for i = 1, str:len() do
    if str[i] == char then
      hits = hits + 1
    end
  end

  return hits
end

--- Fixes the spelling of a sentence: capitalizes its first letter and appends a period, unless
-- it already ends with '.', '!', '?' or '"'. Strings in full uppercase keep their letter case.
-- @param str [String]
-- @param first_lower=false [Boolean make the first letter lowercase instead of uppercase]
-- @param no_period=false [Boolean do not append the period]
-- @return [String the corrected string]
function string.spelling(str, first_lower, no_period)
  local len = utf8.len(str)
  local end_text = String.sub(str, -1)
  local first_char = String.sub(str, 1, 1)

  if !str:is_upper() then
    str = (!first_lower and String.upper(String.sub(str, 1, 1)) or
          String.lower(String.sub(str, 1, 1)))..String.sub(str, 2, len)
  end

  if !no_period then
    if end_text != '.' and end_text != '!' and end_text != '?' and end_text != '"' then
      str = str..'.'
    end
  end

  return str
end

--- Returns the string itself if it is not empty.
-- @param str [Any value to check]
-- @return [String the same string, or nil if it is empty or not a string at all]
function string.presence(str)
  return isstring(str) and (str != '' and str) or nil
end

--- Converts a ConstantStyle or camelCase string to snake_case.
-- Namespace separators (`::`) become slashes, dashes and whitespace become underscores.
-- ```
-- ('ActiveRecord::Base'):underscore() -- 'active_record/base'
-- ```
-- @param str [String]
-- @return [String the snake_case string]
function string.underscore(str)
  return str:gsub('::', '/')
            :gsub('([A-Z]+)([A-Z][a-z])', '%1_%2')
            :gsub('([a-z%d])([A-Z])', '%1_%2')
            :gsub('[%-%s]', '_')
            :lower()
end

--- Converts a snake_case string to ConstantStyle, such as 'active_record' to 'ActiveRecord'.
-- @param str [String]
-- @return [String the converted string, Number amount of underscores that were removed]
function string.camel_case(str)
  return str:capitalize():gsub('_([a-z])', string.upper)
end

--- Removes all newlines (\n and \r) from the end of the string. If `what` is given, removes all
-- occurrences of it from both the beginning and the end of the string instead.
-- @param str [String]
-- @param what=nil [String substring to remove from both ends]
-- @return [String the trimmed string]
function string.chomp(str, what)
  if !what then
    str = str:trim_end('\n', true):trim_end('\r', true)
  else
    str = str:trim_start(what, true):trim_end(what, true)
  end

  return str
end

--- Converts the first character of the string to uppercase.
-- @param str [String]
-- @return [String]
function string.capitalize(str)
  local len = utf8.len(str)
  return String.upper(str[1])..(len > 1 and String.sub(str, 2, utf8.len(str)) or '')
end

--- Finds the table that a `::`-separated path such as 'ActiveRecord::Base' points to.
-- ```
-- local base_class = ('ActiveRecord::Base'):parse_table() -- same as _G.ActiveRecord.Base
-- ```
-- @param str [String path to the table]
-- @param ref=_G [Map table to start the lookup from]
-- @return [Map/Boolean the table or false if it was not found, String the part of the path
--   that is not a table (only on failure)]
function string.parse_table(str, ref)
  local tables = str:split('::')

  ref = istable(ref) and ref or _G

  for k, v in ipairs(tables) do
    ref = ref[v]

    if !istable(ref) then return false, v end
  end

  return ref
end

--- Follows a `::`-separated path for as long as it points to existing tables. Returns the last
-- table it reached and the name to look up or create in it.
-- ```
-- -- While Flux exists and Flux.Thing does not:
-- local parent, name = ('Flux::Thing'):parse_parent() -- Flux, 'Thing'
-- local parent, name = ('Thing'):parse_parent()       -- _G, 'Thing'
-- ```
-- @param str [String path to the table]
-- @param ref=_G [Map table to start the lookup from]
-- @return [Map the last existing table on the path, String the first part of the path that is
--   not a table (the last part if the whole path already exists)]
function string.parse_parent(str, ref)
  local tables = str:split('::')
  local last_ref = str

  ref = istable(ref) and ref or _G

  for k, v in ipairs(tables) do
    local new_ref = ref[v]

    if !istable(new_ref) then return ref, v end

    last_ref = v

    ref = new_ref
  end

  if istable(ref) then
    return ref, last_ref or str
  else
    return false
  end
end

local function real_gsub(pat)
  return pat:gsub("(%%?)(.)", function(percent, letter)
    if percent != "" or !letter:match("%a") then
      return percent..letter
    else
      return string.format("[%s%s]", letter:lower(), letter:upper())
    end
  end)
end

-- https://stackoverflow.com/questions/11401890/case-insensitive-lua-pattern-matching

--- Makes a Lua pattern case-insensitive.
-- ```
-- inflect:plural(i'(octop)us$', '%1i') -- the pattern becomes '([oO][cC][tT][oO][pP])[uU][sS]$'
-- ```
-- @param pattern [String Lua pattern]
-- @return [String pattern that matches both lowercase and uppercase letters]
function i(pattern)

  if pattern:include('[') then
    local p = pattern:gsub('([.]*)%[([%w]*)%]([.]*)', function(before, letters, after)
      return real_gsub(before)..'['..letters:lower()..letters:upper()..']'..real_gsub(after)
    end)
    return p
  else
    local p = real_gsub(pattern)
    return p
  end
end

--- Replaces the `{name}` placeholders in a string with the values from a hash.
-- Placeholders that have no value are removed.
-- ```
-- string.fmt('{count} {id} were registered.', { id = 'tools', count = 5 })
-- -- '5 tools were registered.'
-- ```
-- @param format [String text with placeholders made of letters, digits and underscores]
-- @param data={} [Map placeholder name => String/Number value]
-- @return [String the formatted string, Number amount of placeholders that were replaced]
function string.fmt(format, data)
  data = istable(data) and data or {}

  return string.gsub(format, '{([%w_]+)}', function(hit)
    return data[hit] or ''
  end)
end

--- Escapes the control characters (\a, \b, \f, \n, \r, \t and \v) in a string, so that they
-- appear as their backslash sequences.
-- @param str [String]
-- @return [String the escaped string, Number amount of \v characters that were escaped]
function string.escape(str)
  return str:gsub('\a', '\\a')
            :gsub('\b', '\\b')
            :gsub('\f', '\\f')
            :gsub('\n', '\\n')
            :gsub('\r', '\\r')
            :gsub('\t', '\\t')
            :gsub('\v', '\\v')
end
