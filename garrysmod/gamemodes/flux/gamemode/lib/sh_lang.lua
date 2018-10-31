library.new('lang', fl)

local stored = fl.lang.stored or {}
fl.lang.stored = stored

local current_language = 'en'

local default_lang_table = {
  nice_time = function(self, time)
    if time == 1 then
      return t('time.seconds.1', time), 0
    elseif time < 60 then
      return t('time.seconds.2', time), 0
    elseif time < (60 * 60) then
      local _t = math.floor(time / 60)
      return t('time.minutes.'..(_t != 1 and '2') or '1', _t), time - _t * 60
    elseif time < (60 * 60 * 24) then
      local _t = math.floor(time / 60 / 60)
      return t('time.hours.'..(_t != 1 and '2') or '1', _t), time - _t * 60 * 60
    elseif time < (60 * 60 * 24 * 7) then
      local _t = math.floor(time / 60 / 60 / 24)
      return t('time.days.'..(_t != 1 and '2') or '1', _t), time - _t * 60 * 60 * 24
    elseif time < (60 * 60 * 24 * 30) then
      local _t = math.floor(time / 60 / 60 / 24 / 7)
      return t('time.weeks.'..(_t != 1 and '2') or '1', _t), time - _t * 60 * 60 * 24 * 7
    elseif time < (60 * 60 * 24 * 30 * 12) then
      local _t = math.floor(time / 60 / 60 / 24 / 30)
      return t('time.months.'..(_t != 1 and '2') or '1', _t), time - _t * 60 * 60 * 24 * 30
    elseif time >= (60 * 60 * 24 * 365) then
      local _t = math.floor(time / 60 / 60 / 24 / 365)
      return t('time.years.'..(_t != 1 and '2') or '1', _t), time - _t * 60 * 60 * 24 * 365
    else
      return t('time.seconds.2', time), 0
    end
  end,
  nice_time_full = function(self, time)
    local out = ''
    local i = 0

    while time > 0 do
      if i >= 100 then break end -- fail safety

      local str, remainder = self:nice_time(time)

      time = remainder

      if time <= 0 then
        if i != 0 then
          out = out..t('time.and')..str
        else
          out = str
        end
      else
        out = out..str..' '
      end

      i = i + 1
    end

    return out
  end
}

function fl.lang:get_phrase(id, ref)
  ref = ref or stored

  local tables = id:split('.')

  for k, v in ipairs(tables) do
    local val = ref[v]
    if istable(val) then
      ref = val
    else
      return val
    end
  end

  return false
end

function t(phrase, args, force_lang)
  args = istable(args) and args or { args }
  local phrase = fl.lang:get_phrase(phrase, stored[force_lang or current_language]) or phrase

  for k, v in pairs(args) do
    phrase = string.gsub(phrase, '{'..k..'}', v)
  end

  return phrase
end

-- Pack the language string into a format that is sendable to clients.
function L(phrase, args)
  ErrorNoHalt('"L" is deprecated and will be removed in 0.5! Do not use it!')
  return phrase, args
end

function fl.lang:all()
  return stored
end

function fl.lang:add(index, value, reference)
  reference = reference or stored

  if istable(value) then
    reference[index] = reference[index] or {}
    for k, v in pairs(value) do
      self:add(k, v, reference[index])
    end
  else
    reference[index] = value
  end
end

function fl.lang:get_plural(language, phrase, count)
  local lang_table = stored[language]
  local translated = t(phrase)

  if !lang_table then return translated end

  if lang_table.pluralize then
    return lang_table:pluralize(phrase, count, translated)
  elseif language == 'en' then
    if !string.vowel(translated:sub(translated:len(), translated:len())) then
      return translated..'es'
    else
      return translated..'s'
    end
  end

  return translated
end

function fl.lang:nice_time(language, time)
  time = tonumber(time) or 0

  local lang_table = stored[language]

  if lang_table and lang_table.nice_time then
    return lang_table:nice_time(time)
  end

  return string.nice_time(time)
end

function fl.lang:nice_time_full(language, time)
  time = tonumber(time) or 0

  local lang_table = stored[language]

  if lang_table and lang_table.nice_time_full then
    return lang_table:nice_time_full(time)
  end

  return string.nice_time(time)
end

function fl.lang:get_case(language, phrase, case)
  if language == 'en' then return t(phrase) end

  local lang_table = stored[language]
  local translated = t(phrase)

  if !lang_table then return translated end

  if lang_table.get_case then
    return lang_table:get_case(phrase, count, translated)
  end

  return translated
end

function fl.lang:get_player_lang(player)
  if !IsValid(player) then return 'en' end

  return player:get_nv('language', 'en')
end

if CLIENT then
  function fl.lang:pluralize(phrase, count)
    local lang = GetConVar('gmod_language'):GetString()

    if lang then
      return self:get_plural(lang, phrase, count)
    end
  end

  function fl.lang:case(phrase, case)
    local lang = GetConVar('gmod_language'):GetString()

    if lang then
      return self:get_case(lang, phrase, case)
    end
  end

  hook.Add('LazyTick', 'LanguageChecker', function()
    local new_lang = GetConVar('gmod_language'):GetString()

    if current_language != new_lang then
      current_language = new_lang

      cable.send('player_set_lang', new_lang)
    end
  end)
else
  pipeline.register('language', function(id, file_name, pipe)
    if file_name:ends('.yml') then
      local contents = fileio.Read('gamemodes/'..file_name)

      if contents then
        for k, v in pairs(YAML.eval(contents)) do
          fl.lang:add(k, v)
        end
      end
    end
  end)
end
