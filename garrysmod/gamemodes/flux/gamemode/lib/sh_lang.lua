library 'Flux::Lang'

local stored = Flux.Lang.stored or {}
Flux.Lang.stored = stored

local current_language = 'en'

function Flux.Lang:get_phrase(id, ref)
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

  local phrase = Flux.Lang:get_phrase(phrase, stored[force_lang or current_language]) or Flux.Lang:get_phrase(phrase, stored['en']) or phrase

  for k, v in pairs(args) do
    phrase = string.gsub(phrase, '{'..k..'}', v)
  end

  return phrase
end

function Flux.Lang:all()
  return stored
end

function Flux.Lang:add(index, value, reference)
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

function Flux.Lang:get_plural(language, phrase, count)
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

function Flux.Lang:nice_time(time, lang)
  time = tonumber(time) or 0

  return Time:format_nice(Time:nice_from_now(Time:now() + Time:seconds(time)), lang)
end

function Flux.Lang:get_case(language, phrase, case)
  if language == 'en' then return t(phrase) end

  local lang_table = stored[language]
  local translated = t(phrase)

  if !lang_table then return translated end

  if lang_table.get_case then
    return lang_table:get_case(phrase, count, translated)
  end

  return translated
end

function Flux.Lang:get_player_lang(player)
  if !IsValid(player) then return 'en' end

  return player:get_nv('language', 'en')
end

if CLIENT then
  function Flux.Lang:pluralize(phrase, count)
    local lang = GetConVar('gmod_language'):GetString()

    if lang then
      return self:get_plural(lang, phrase, count)
    end
  end

  function Flux.Lang:case(phrase, case)
    local lang = GetConVar('gmod_language'):GetString()

    if lang then
      return self:get_case(lang, phrase, case)
    end
  end

  hook.Add('LazyTick', 'LanguageChecker', function()
    local new_lang = GetConVar('gmod_language'):GetString()

    if current_language != new_lang then
      current_language = new_lang

      Cable.send('fl_player_set_lang', new_lang)
    end
  end)
else
  pipeline.register('language', function(id, file_name, pipe)
    if file_name:ends('.yml') then
      local contents = fileio.Read('gamemodes/'..file_name)

      if contents then
        for k, v in pairs(YAML.eval(contents)) do
          Flux.Lang:add(k, v)
        end
      end
    end
  end)
end
