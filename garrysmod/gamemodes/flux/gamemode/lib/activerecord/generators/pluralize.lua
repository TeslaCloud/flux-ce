local vowels = {
  ['a'] = true, ['e'] = true,
  ['o'] = true, ['i'] = true,
  ['u'] = true, ['y'] = true
}

local irregular_words = {
  data = 'data', ammo = 'ammo'
}

function ActiveRecord.Infector:pluralize(str)
  if irregular_words[str] then return irregular_words[str] end

  local len = str:len()
  local last_char = str[len]:lower()
  local prev_char = str[len - 1]:lower()

  if vowels[last_char] then
    if last_char == 'y' then
      return str:sub(1, len - 1)..'ies'
    elseif last_char == 'e' then
      return str..'s'
    else
      return str..'es'
    end
  else
    if last_char == 's' then
      if prev_char == 'u' then
        return str:sub(1, len - 2)..'i'
      else
        return str..'es'
      end
    else
      return str..'s'
    end
  end
end
