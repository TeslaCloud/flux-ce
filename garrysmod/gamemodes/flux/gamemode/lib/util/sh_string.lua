local string_meta = getmetatable('')

do
  local vowels = {
    ['a'] = true,
    ['e'] = true,
    ['o'] = true,
    ['i'] = true,
    ['u'] = true,
    ['y'] = true
  }

  -- A function to check whether character is vowel or not.
  function string.vowel(char)
    char = char:utf8lower()

    if CLIENT then
      local lang = fl.lang:GetTable(GetConVar('gmod_language'):GetString())

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

-- A function to remove a substring from the end of the string.
function string.trim_end(str, needle, all_occurences)
  if !needle or needle == '' then
    return str
  end

  if str:ends(needle) then
    if all_occurences then
      while str:ends(needle) do
        str = str:trim_end(needle)
      end

      return str
    end

    return str:utf8sub(1, str:utf8len() - needle:utf8len())
  else
    return str
  end
end

-- A function to remove a substring from the beginning of the string.
function string.trim_start(str, needle, all_occurences)
  if !needle or needle == '' then
    return str
  end

  if str:starts(needle) then
    if all_occurences then
      while str:starts(needle) do
        str = str:trim_start(needle)
      end

      return str
    end

    return str:utf8sub(needle:utf8len() + 1, str:utf8len())
  else
    return str
  end
end

-- A function to check whether the string is full uppercase or not.
function string.is_upper(str)
  return string.utf8upper(str) == str
end

-- A function to check whether the string is full lowercase or not.
function string.is_lower(str)
  return string.utf8lower(str) == str
end

-- A function to find all occurences of a substring in a string.
function string.find_all(str, pattern)
  if !str or !pattern then return end

  local hits = {}
  local last_pos = 1

  while true do
    local start_pos, end_pos = string.find(str, pattern, last_pos)

    if !start_pos then
      break
    end

    table.insert(hits, {string.utf8sub(str, start_pos, end_pos), start_pos, end_pos})

    last_pos = end_pos + 1
  end

  return hits
end

-- A function to check if string is command or not.
function string.is_command(str)
  local prefixes = config.get('command_prefixes') or {}

  for k, v in ipairs(prefixes) do
    if str:starts(v) and hook.run('StringIsCommand', str) != false then
      return true, string.utf8len(v)
    end
  end

  return false
end

do
  -- ID's should not have any of those characters.
  local blocked_chars = {
    "'", '"', '\\', '/', '^',
    ':', '.', ';', '&', ',', '%'
  }

  function string.to_id(str)
    str = str:utf8lower()
    str = str:gsub(' ', '_')

    for k, v in ipairs(blocked_chars) do
      str = str:Replace(v, '')
    end

    return str
  end
end

function string.ensure_ending(str, ending)
  if str:ends(ending) then return str end
  return str..ending
end

function string.ensure_start(str, start)
  if str:starts(start) then return str end
  return start..str
end

function string.set_indent(str, indent)
  return indent..str:gsub('\n', '\n'..indent):gsub('\n%s+\n', '\n\n')
end

function string_meta:__add(right)
  return self..tostring(right)
end

function string.is_n(char)
  return tonumber(char) != nil
end

function string.count(str, char)
  local hits = 0

  for i = 1, str:len() do
    if str[i] == char then
      hits = hits + 1
    end
  end

  return hits
end

function string.spelling(str, first_lower)
  local len = str:utf8len()
  local end_text = str:utf8sub(-1)

  str = (!first_lower and str:utf8sub(1, 1):utf8upper() or str:utf8sub(1, 1):utf8lower())..str:utf8sub(2, len)

  if end_text != '.' and end_text != '!' and end_text != '?' and end_text != '"' then
    str = str..'.'
  end

  return str
end

function string.presence(str)
  return isstring(str) and (str != '' and str) or nil
end

function string.underscore(str)
  return str:gsub('::', '/'):
         gsub('([A-Z]+)([A-Z][a-z])', '%1_%2'):
         gsub('([a-z%d])([A-Z])', '%1_%2'):
         gsub('[%-%s]', '_'):
         lower()
end

function string.camel_case(str)
  return str:capitalize():gsub('_([a-z])', string.upper)
end

function string.chomp(str, what)
  if !what then
    str = str:trim_end('\n', true):trim_end('\r', true)
  else
    str = str:trim_start(what, true):trim_end(what, true)
  end

  return str
end

function string.capitalize(str)
  local len = string.utf8len(str)
  return string.utf8upper(str[1])..(len > 1 and string.utf8sub(str, 2, string.utf8len(str)) or '')
end

function string.parse_table(str, ref)
  local tables = str:split('::')

  ref = istable(ref) and ref or _G

  for k, v in ipairs(tables) do
    ref = ref[v]
  
    if !istable(ref) then return false, v end
  end

  return ref
end

function string.parse_parent(str, ref)
  local tables = str:split('::')

  ref = istable(ref) and ref or _G

  for k, v in ipairs(tables) do
    local new_ref = ref[v]

    if !istable(new_ref) then return ref, v end

    ref = new_ref
  end

  if istable(ref) then
    return ref, str
  else
    return false
  end
end
