--- Localization: translates phrases into the language of the player. The phrases come from the
-- YAML files in the `languages` folders of Flux, the schema and the plugins, where they are
-- nested under the language code; the server reads the files and sends the phrases to the
-- clients. A phrase is referred to by its path with dots, such as 'ui.hud.bar_text.respawn',
-- and translated with the global `t` function, which also fills in the `{placeholders}` of the
-- phrase. Text that is not a known phrase is returned as it is, so `t` can be given text that
-- may or may not be a phrase.
--
-- On the client the current language follows the `gmod_language` setting of the game and is
-- reported to the server, where `Flux.Lang:get_player_lang` returns it for a player. On the
-- server `t` translates to English unless it is given a language. Phrases can also be added
-- from code with `Flux.Lang:add`, and a language can define `pluralize` and `get_case`
-- functions for its grammar, which `Flux.Lang:get_plural` and `Flux.Lang:get_case` use.
-- @module [Flux.Lang]

mod 'Flux::Lang'

local current_language  = 'en'
local stored            = Flux.Lang.stored or {}
Flux.Lang.stored        = stored

do
  local function _get_phrase(tabs, ref)
    if !ref then
      ref = stored['en']

      if !ref then return false end
    end

    for k, v in ipairs(tabs) do
      local val = ref[v]

      if istable(val) then
        ref = val
      else
        return val
      end
    end

    return false
  end

  --- Translates a phrase to the current language. English is used if the language is not
  -- available, and the phrase itself is returned if it has no translation. Line breaks
  -- in the result are replaced with spaces.
  -- ```
  -- local text = t'ui.char_create.unknown_error'
  -- -- Replaces {name} in the translated phrase.
  -- local message = t('ui.char_create.delete_confirm_msg', { name = self.char_data.name })
  -- ```
  -- @param phrase [String phrase ID with its nesting separated by dots, or plain text]
  -- @param args=nil [Map/Any values to replace the {key} placeholders with, by key;
  --   a single value replaces {1}]
  -- @param force_lang=nil [String language code to use instead of the current language]
  -- @return [String translated text, Number amount of line breaks that were replaced]
  function t(phrase, args, force_lang)
    args = istable(args) and args or { args }

    local tabs = phrase:split('.')
    local phrase = _get_phrase(tabs, stored[force_lang or current_language]) or phrase

    for k, v in pairs(args) do
      phrase = string.gsub(phrase, '{'..k..'}', v)
    end

    return phrase:gsub('\n', ' ')
  end
end

--- Returns all of the stored phrases.
-- @return [Map nested tables of phrases by language code]
function Flux.Lang:all()
  return stored
end

--- Adds a phrase, or a table of phrases that is merged into the existing ones recursively.
-- ```
-- -- Makes t'my_plugin.greeting' available in English.
-- Flux.Lang:add('en', {
--   my_plugin = {
--     greeting = 'Hello, {name}!'
--   }
-- })
-- ```
-- @param index [String language code, or the key of the phrase inside the reference table]
-- @param value [String/Map phrase or a nested table of phrases]
-- @param reference=nil [Map table to add to, all stored phrases by default]
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

--- Translates a phrase and puts it in plural form using the rules of the specified language.
-- Languages define the rules with a pluralize function in their language table.
-- @param language [String language code]
-- @param phrase [String phrase ID]
-- @param count [Number amount of things, for languages with several plural forms]
-- @return [String]
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

--- Converts an amount of seconds into human readable text, such as '2 hours from now'.
-- @param time [Number/String seconds from now]
-- @param lang=nil [String language code, the current language by default]
-- @return [String]
function Flux.Lang:nice_time(time, lang)
  lang = lang or current_language

  if !isnumber(time) then
    time = tonumber(time) or 0
  end

  return Time:format_nice(Time:nice_from_now(DateTime:now() + Time:seconds(time)), lang)
end

--- Translates a phrase and puts it in a grammatical case using the rules of the specified
-- language. Languages define the rules with a get_case function in their language table.
-- @param language [String language code]
-- @param phrase [String phrase ID]
-- @param case [String grammatical case]
-- @return [String]
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

--- Returns the language of a player.
-- @param target [Player]
-- @return [String language code, 'en' if the player is not valid or has not sent it yet]
function Flux.Lang:get_player_lang(target)
  if !IsValid(target) then return 'en' end

  return target:get_nv('language', 'en')
end

if CLIENT then
  --- Translates a phrase and puts it in plural form using the rules of the game's language.
  -- Clientside only.
  -- @param phrase [String phrase ID]
  -- @param count [Number amount of things]
  -- @return [String]
  -- @see [Flux.Lang#get_plural]
  function Flux.Lang:pluralize(phrase, count)
    local lang = GetConVar('gmod_language'):GetString()

    if lang then
      return self:get_plural(lang, phrase, count)
    end
  end

  --- Translates a phrase and puts it in a grammatical case using the rules of the game's
  -- language. Clientside only.
  -- @param phrase [String phrase ID]
  -- @param case [String grammatical case]
  -- @return [String]
  -- @see [Flux.Lang#get_case]
  function Flux.Lang:case(phrase, case)
    local lang = GetConVar('gmod_language'):GetString()

    if lang then
      return self:get_case(lang, phrase, case)
    end
  end

  --- Follows the `gmod_language` setting of the game: when it changes, switches the current
  -- language of the client and tells the server the new language of the local player.
  hook.Add('LazyTick', 'LanguageChecker', function()
    local new_lang = GetConVar('gmod_language'):GetString()

    if current_language != new_lang then
      current_language = new_lang

      Cable.send('fl_player_set_lang', new_lang)
    end
  end)
else
  Pipeline.register('language', function(id, file_name, pipe)
    if file_name:end_with('.yml') then
      local contents = File.read('gamemodes/'..file_name)

      if contents then
        for k, v in pairs(YAML.eval(contents)) do
          Flux.Lang:add(k, v)
        end
      end
    end
  end)
end
