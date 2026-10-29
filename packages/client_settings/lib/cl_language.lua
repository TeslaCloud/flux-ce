--- The language setting: a choice between following the language of the game and every
-- language the server has phrases for. Picking one goes through `Flux.Lang:set_language`, and
-- the setting follows the language the player has picked in the fl_language console
-- variable, which can be changed there directly. The console variable is left alone when the
-- setting follows it.

local following = false

--- Switches the language of the client to the one the player has picked in the settings
-- menu.
-- @param value [String language code, or an empty string to follow the language of the game]
local function language_picked(value)
  if following then return end

  following = true
  Flux.Lang:set_language(value)
  following = false
end

--- Makes the language setting show the language the player has actually picked, which is
-- kept in the fl_language console variable. A language that this server has no phrases for
-- is shown as following the game.
function ClientSettings:follow_language()
  if following or !self:find('language') then return end

  local lang = Flux.Lang:get_language_override() or ''

  if self:sanitize('language', lang) == nil then
    lang = ''
  end

  if self:get('language') != lang then
    following = true
    self:set('language', lang)
    following = false
  end
end

local choices = { { value = '', name = 'settings.language.auto' } }

for _, lang in ipairs(Flux.Lang:get_languages()) do
  choices[#choices + 1] = { value = lang, name = Flux.Lang:get_language_name(lang) }
end

ClientSettings:register_setting('language', {
  type = 'choice',
  default = '',
  choices = choices,
  category = 'settings.categories.interface',
  name = 'settings.language.name',
  description = 'settings.language.desc',
  on_change = language_picked
})

ClientSettings:follow_language()

--- Keeps the language setting in step when the fl_language console variable changes without
-- the language of the client changing with it, which is the case when it is cleared while
-- the game is set to the same language.
cvars.AddChangeCallback('fl_language', function(_name, _old_value, _new_value)
  ClientSettings:follow_language()
end, 'LanguageSetting')
