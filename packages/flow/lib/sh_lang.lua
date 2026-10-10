--- Localization: translates phrases into the language of the player. The phrases come from the
-- YAML files in the `languages` folders of Flux, the schema and the plugins, where they are
-- nested under the language code; the server reads the files and sends the phrases to the
-- clients. A phrase is referred to by its path with dots, such as 'ui.hud.bar_text.respawn',
-- and translated with the global `t` function, which also fills in the `{placeholders}` of the
-- phrase. Text that is not a known phrase is returned as it is, so `t` can be given text that
-- may or may not be a phrase. A phrase that the language has no translation for is taken
-- from English.
--
-- A phrase that depends on a number can have plural forms: instead of a text it is a table
-- of texts under the keys '1', '2' and '5', and `t` picks the one that fits the number among
-- its arguments. English only uses '1' (one thing) and '2' (several); Russian uses all three:
-- ```
-- ru:
--   time:
--     hours:
--       "1": час
--       "2": часа
--       "5": часов
-- ```
-- Which form a number takes is decided by the plural rule of the language. Flux has the rules
-- of English, which is also used for languages without a rule of their own, and of Russian;
-- `Flux.Lang:set_plural_rule` adds others.
--
-- On the client the current language follows the `gmod_language` setting of the game, unless
-- the player has picked another one: `Flux.Lang:set_language` overrides it and remembers the
-- choice in the `fl_language` console variable. `Flux.Lang:get_languages` and
-- `Flux.Lang:get_language_name` list the languages to pick from. Either way the language is
-- reported to the server, where `Flux.Lang:get_player_lang` returns it for a player. On the
-- server `t` translates to English unless it is given a language, so text that depends on the
-- language of the reader should be built on the client: `Flux.Lang:duration` does that for the
-- durations in notifications. Phrases can also be added from code with `Flux.Lang:add`, and a
-- language can define a `get_case` function for its grammar, which `Flux.Lang:get_case` uses.
-- @module [Flux.Lang]

mod 'Flux::Lang'

local istable           = istable
local isstring          = isstring
local tonumber          = tonumber
local tostring          = tostring
local pairs             = pairs
local string_find       = string.find
local string_replace    = string.Replace

local current_language  = Flux.Lang.current or 'en'
local stored            = Flux.Lang.stored or {}
Flux.Lang.stored        = stored
local plural_rules      = Flux.Lang.plural_rules or {}
Flux.Lang.plural_rules  = plural_rules
local form_fallbacks    = { '5', '2', '1' }

--- Plural rule of English: one thing takes the '1' form, any other amount the '2' form.
-- Languages without a rule of their own use it too.
-- @param count [Number amount of things]
-- @return [String '1' or '2']
plural_rules['en'] = function(count)
  return count == 1 and '1' or '2'
end

--- Plural rule of Russian: '1' for amounts that end in 1 but not in 11 (1, 21, 101), '2' for
-- those that end in 2 to 4 but not in 12 to 14 (2, 23, 104) and for fractions, and '5' for
-- everything else (0, 5, 11, 14, 100).
-- @param count [Number amount of things]
-- @return [String '1', '2' or '5']
plural_rules['ru'] = function(count)
  count = math.abs(count)

  if count % 1 != 0 then return '2' end

  local last_digit, last_two = count % 10, count % 100

  if last_digit == 1 and last_two != 11 then
    return '1'
  elseif last_digit >= 2 and last_digit <= 4 and (last_two < 12 or last_two > 14) then
    return '2'
  end

  return '5'
end

do
  local function _get_phrase(tabs, ref)
    if !ref then
      ref = stored['en']

      if !ref then return false end
    end

    for i = 1, #tabs do
      local val = ref[tabs[i]]

      if istable(val) then
        ref = val
      else
        return val
      end
    end

    return ref
  end

  local function _get_count(args)
    local count = tonumber(args.count or args.amount)

    if count then return count end

    for k, v in pairs(args) do
      if isnumber(v) then
        if count then return end

        count = v
      end
    end

    return count
  end

  local function _get_form(forms, lang, count)
    local key = count and Flux.Lang:get_plural_form(lang, count)
    local form = key and (forms[key] or forms[tonumber(key)])

    if isstring(form) then return form end

    for i = 1, #form_fallbacks do
      local fallback = form_fallbacks[i]

      form = forms[fallback] or forms[tonumber(fallback)]

      if isstring(form) then return form end
    end
  end

  --- Looks a phrase up in one language and picks the plural form that fits the arguments.
  -- @param tabs [List<String> the parts of the phrase ID]
  -- @param lang [String language code]
  -- @param args [Map arguments of the phrase]
  -- @return [String the text of the phrase, nil or false if the language does not have it]
  local function _translate(tabs, lang, args)
    local translated = _get_phrase(tabs, stored[lang])

    if istable(translated) then
      translated = _get_form(translated, lang, _get_count(args))
    end

    return translated
  end

  local phrase_parts = {}
  local no_args = {}

  --- Translates a phrase to the current language. English is used if the language is not
  -- available or does not have the phrase, and the phrase itself is returned if it has no
  -- translation at all. Line breaks in the result are replaced with spaces.
  -- ```
  -- local text = t'ui.char_create.unknown_error'
  -- -- Replaces {name} in the translated phrase.
  -- local message = t('ui.char_create.delete_confirm_msg', { name = self.char_data.name })
  -- ```
  --
  -- A phrase with plural forms is translated to the form that fits a number. The number is
  -- the `count` argument, else the `amount` argument, else the only number among the
  -- arguments; without one the most general form is used ('5', else '2', else '1').
  -- ```
  -- -- 'RESPAWNING IN 1 SECOND.' or 'RESPAWNING IN 5 SECONDS.',
  -- -- 'ВОЗРОЖДЕНИЕ ЧЕРЕЗ 2 СЕКУНДЫ' or 'ВОЗРОЖДЕНИЕ ЧЕРЕЗ 5 СЕКУНД' in Russian.
  -- local text = t('ui.hud.player_message.respawn', { time = seconds })
  -- ```
  -- @param phrase [String phrase ID with its nesting separated by dots, or plain text]
  -- @param args=nil [Map/Any values to replace the {key} placeholders with, by key;
  --   a single value replaces {1}. A value is inserted as it is, so text that a player has
  --   typed needs no escaping. A value made by `Flux.Lang:duration` is replaced with the
  --   duration as text]
  -- @param force_lang=nil [String language code to use instead of the current language]
  -- @return [String translated text, Number amount of line breaks that were replaced]
  -- @see [Flux.Lang#get_plural_form]
  function t(phrase, args, force_lang)
    if args == nil then
      args = no_args
    elseif !istable(args) then
      args = { args }
    end

    local lang = force_lang or current_language

    if !stored[lang] then
      lang = 'en'
    end

    local tabs = phrase_parts[phrase] or phrase:split('.')
    local translated = _translate(tabs, lang, args)

    if !translated and lang != 'en' then
      translated = _translate(tabs, 'en', args)
    end

    if translated then
      phrase_parts[phrase] = tabs
      phrase = translated
    end

    if string_find(phrase, '{', 1, true) then
      for k, v in pairs(args) do
        if istable(v) and v.nice_time then
          v = Flux.Lang:nice_time(v.nice_time, lang)
        end

        phrase = string_replace(phrase, '{'..k..'}', tostring(v))
      end
    end

    if !string_find(phrase, '\n', 1, true) then
      return phrase, 0
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

--- Sets the plural rule of a language: the function that decides which plural form of a
-- phrase an amount takes.
-- ```
-- -- Polish has the same three forms as Russian, with a different rule for the first one.
-- Flux.Lang:set_plural_rule('pl', function(count)
--   if count == 1 then return '1' end
--
--   local last_digit, last_two = count % 10, count % 100
--
--   if last_digit >= 2 and last_digit <= 4 and (last_two < 12 or last_two > 14) then
--     return '2'
--   end
--
--   return '5'
-- end)
-- ```
-- @param language [String language code]
-- @param rule [Function called with the amount; returns the key of the form to use: '1',
--   '2' or '5']
function Flux.Lang:set_plural_rule(language, rule)
  plural_rules[language] = rule
end

--- Returns the key of the plural form that an amount takes in a language: '1', '2' or '5',
-- named after the smallest amount that takes the form in Russian. Languages without a
-- plural rule use the rule of English, which only knows '1' and '2'.
-- @param language [String language code]
-- @param count [Number amount of things]
-- @return [String key of the plural form]
-- @see [Flux.Lang#set_plural_rule]
function Flux.Lang:get_plural_form(language, count)
  return tostring((plural_rules[language] or plural_rules['en'])(count))
end

--- Translates a phrase to the specified language, in the plural form that fits the amount.
-- A phrase without plural forms is translated as it is.
-- @param language [String language code]
-- @param phrase [String phrase ID]
-- @param count [Number amount of things, which also replaces {count} in the phrase]
-- @return [String]
function Flux.Lang:get_plural(language, phrase, count)
  return (t(phrase, { count = count }, language))
end

--- Makes a phrase argument that stands for a duration. `t` replaces it with the same text
-- that `Flux.Lang:nice_time` returns, in the language the phrase is translated to. Use it
-- for notifications, which are translated on the client of each recipient, so that everyone
-- reads the duration in their own language.
-- ```
-- -- 'You have been muted for about 2 hours.' or 'Вам был отключен ООС чат на 2 часа.'
-- target:notify('notification.muted', { time = Flux.Lang:duration(7200) })
-- ```
-- @param seconds [Number amount of seconds]
-- @return [Map value to pass as a phrase argument]
-- @see [Flux.Lang#nice_time]
function Flux.Lang:duration(seconds)
  return { nice_time = tonumber(seconds) or 0 }
end

--- Converts an amount of seconds into a human readable duration, such as 'about 2 hours'.
-- A duration of less than 15 seconds is given in seconds too, and never as less than
-- '1 second', so that the result can always be put after a word like 'for' or 'in'.
-- @param time [Number/String amount of seconds]
-- @param lang=nil [String language code, the current language by default]
-- @return [String]
function Flux.Lang:nice_time(time, lang)
  lang = lang or current_language

  if !isnumber(time) then
    time = tonumber(time) or 0
  end

  local suffix, from_now, amount = Time:seconds(time):nice()

  if suffix == 'time.just_now' then
    suffix = amount < 2 and 'time.second' or 'time.seconds'
  end

  return Time:format_nice(suffix, '', amount, lang)
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
    return lang_table:get_case(phrase, case, translated)
  end

  return translated
end

--- Returns the language of a player: the one their client has reported, which is the
-- language they picked with `Flux.Lang:set_language` or else the language of their game.
-- @param target [Player]
-- @return [String language code, 'en' if the player is not valid or has not sent it yet]
function Flux.Lang:get_player_lang(target)
  if !IsValid(target) then return 'en' end

  return target:get_nv('language', 'en')
end

--- Returns the language that `t` translates to when it is not given one.
-- @return [String language code; always 'en' on the server]
function Flux.Lang:get_language()
  return current_language
end

--- Returns the languages that have phrases, for a language picker.
-- @return [List<String> language codes in alphabetical order]
function Flux.Lang:get_languages()
  local languages = {}

  for k, v in pairs(stored) do
    if istable(v) then
      languages[#languages + 1] = k
    end
  end

  table.sort(languages)

  return languages
end

--- Returns the name of a language in that language, such as 'English' or 'Русский'. It is
-- the `language.name` phrase of the language.
-- @param lang [String language code]
-- @return [String the name, or the language code if the language does not have one]
function Flux.Lang:get_language_name(lang)
  local lang_table = stored[lang]
  local names = istable(lang_table) and lang_table.language
  local name = istable(names) and names.name

  return isstring(name) and name or lang
end

if CLIENT then
  local override = CreateClientConVar('fl_language', '', true, false,
    'Language of the Flux interface. Leave empty to use the language of the game.')
  local game_language = GetConVar('gmod_language')

  --- Returns the language the local player has picked instead of the language of the game.
  -- Clientside only.
  -- @return [String language code, nil if the player follows the language of the game]
  function Flux.Lang:get_language_override()
    local lang = override:GetString()

    if lang != '' then
      return lang
    end
  end

  --- Returns the language the client should use: the one the player has picked, if it has
  -- phrases, and the `gmod_language` setting of the game otherwise. Clientside only.
  -- @return [String language code]
  function Flux.Lang:get_preferred_language()
    local lang = override:GetString()

    if lang != '' and stored[lang] then
      return lang
    end

    return game_language:GetString()
  end

  --- Switches the current language of the client. Tells the server the new language of the
  -- local player, once the local player exists, and runs the `LanguageChanged` hook.
  -- @param new_lang [String language code]
  local function apply_language(new_lang)
    local old_lang = current_language

    if old_lang == new_lang then return end

    current_language = new_lang
    Flux.Lang.current = new_lang

    if IsValid(LocalPlayer()) then
      Cable.send('fl_player_set_lang', new_lang)
    end

    --- Called on the client when the language that `t` translates to has changed, because
    -- the player picked another one with `Flux.Lang:set_language` or changed the language
    -- of the game. Interface elements that keep translated text can rebuild it here.
    -- @param new_lang [String New language code]
    -- @param old_lang [String Previous language code]
    hook.Run('LanguageChanged', new_lang, old_lang)
  end

  --- Sets the language of the local player, instead of following the `gmod_language`
  -- setting of the game. The choice is kept in the `fl_language` console variable, which
  -- the game saves, takes effect right away and is reported to the server, so that
  -- `Flux.Lang:get_player_lang` returns it there. Clientside only.
  -- ```
  -- Flux.Lang:set_language('ru')
  -- -- Back to the language of the game.
  -- Flux.Lang:set_language(nil)
  -- ```
  -- @param lang=nil [String language code, one of Flux.Lang#get_languages; nil or an empty
  --   string to follow the language of the game again]
  -- @return [Boolean false if there are no phrases for the language, in which case nothing
  --   changes]
  function Flux.Lang:set_language(lang)
    lang = lang or ''

    if !isstring(lang) or (lang != '' and !stored[lang]) then return false end

    override:SetString(lang)

    apply_language(lang != '' and lang or game_language:GetString())

    return true
  end

  --- Translates a phrase to the current language of the client, in the plural form that
  -- fits the amount. Clientside only.
  -- @param phrase [String phrase ID]
  -- @param count [Number amount of things]
  -- @return [String]
  -- @see [Flux.Lang#get_plural]
  function Flux.Lang:pluralize(phrase, count)
    return self:get_plural(current_language, phrase, count)
  end

  --- Translates a phrase and puts it in a grammatical case using the rules of the current
  -- language of the client. Clientside only.
  -- @param phrase [String phrase ID]
  -- @param case [String grammatical case]
  -- @return [String]
  -- @see [Flux.Lang#get_case]
  function Flux.Lang:case(phrase, case)
    return self:get_case(current_language, phrase, case)
  end

  if !Flux.Lang.current then
    current_language = Flux.Lang:get_preferred_language()
    Flux.Lang.current = current_language
  end

  --- Follows the language the player has picked and the `gmod_language` setting of the
  -- game: when the preferred language changes, switches the current language of the client
  -- and tells the server the new language of the local player.
  hook.Add('LazyTick', 'LanguageChecker', function()
    apply_language(Flux.Lang:get_preferred_language())
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
