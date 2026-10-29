--- The shared `Characters` functions and the gender values of characters.
-- A player owns a list of characters and has at most one active character at a time; the
-- player methods that return them are in `lib/meta`. The functions that create, save,
-- delete, ban and edit characters are in `sv_character.lua`. A request of a player to load or
-- delete a character is checked first: `Characters.can_use` and `Characters.can_delete` apply
-- the rules of the plugin and run the `PlayerCanUseCharacter`, `PlayerCanSwitchCharacter` and
-- `PlayerCanDeleteCharacter` hooks, and a refused request is answered with a reason that the
-- menu shows.
--
-- Every character also has generic data: a table of values kept under string keys, saved with
-- the character in its `data` column and read and written with `Player:get_character_data`
-- and `Player:set_character_data` (or `Character:get_data` and `Character:set_data`). The
-- data stays on the server unless a key is passed to `Characters.network_data`, which makes
-- the server send the value of that key to the owner of the character, and to nobody else.
-- @module [Characters]

local isnumber = isnumber
local isstring = isstring
local istable = istable
local config_get = Config.get
local string_trim = string.Trim

if !Characters then
  PLUGIN:set_global('Characters')
end

Characters.networked_data = Characters.networked_data or {}

CHAR_GENDER_MALE = 0
CHAR_GENDER_FEMALE = 1
CHAR_GENDER_NONE = 2

--- The name of every CHAR_GENDER_* value: 'male', 'female' or 'no_gender'.
Characters.gender_names = {
  [CHAR_GENDER_MALE] = 'male',
  [CHAR_GENDER_FEMALE] = 'female',
  [CHAR_GENDER_NONE] = 'no_gender'
}

--- Makes the server send a key of the generic character data to the owner of the character.
-- Without it the data never leaves the server. Once a key is registered, its value is part of
-- the character list that the owner receives and is sent again whenever it is set, so the
-- owner can read it with `Player:get_character_data`; other players never receive it. Call
-- it while the plugin that owns the key loads. It only has an effect on the server, but may
-- be called on both realms.
-- ```
-- Characters.network_data('flags')
-- ```
-- @param key [String key of the character data]
function Characters.network_data(key)
  if !isstring(key) then return end

  Characters.networked_data[key] = true
end

--- Checks whether a key of the generic character data is sent to the owner of the character.
-- @param key [String key of the character data]
-- @return [Boolean]
function Characters.is_data_networked(key)
  return Characters.networked_data[key] == true
end

--- Returns a value from the generic data of a character.
-- On the client only the keys registered with `Characters.network_data` are known, and only
-- for the characters of the local player.
-- @param character [Character/Map character record, or networked character data on the client]
-- @param key [String]
-- @param default=nil [Any value to return when nothing is stored under the key]
-- @return [Any]
function Characters.get_custom_data(character, key, default)
  local custom_data = istable(character) and character.custom_data

  if istable(custom_data) and custom_data[key] != nil then
    return custom_data[key]
  end

  return default
end

--- Returns how many characters a player may have: the `characters_limit` config, unless a
-- GetCharacterLimit hook returns another number.
-- @param target [Player]
-- @return [Number]
function Characters.get_limit(target)
  local limit = config_get('characters_limit', 5)
  --- Lets plugins change how many characters a player may have. Called on the server when a
  -- character is about to be created, and on the client for the local player when the main
  -- menu decides whether the creation screen may be opened, so a handler that is meant to be
  -- seen in the menu has to be shared.
  -- @param target [Player the player whose limit is requested]
  -- @param limit [Number the value of the characters_limit config]
  -- @return [Number the limit to use for this player; return nothing to keep the config value]
  local adjusted = hook.Run('GetCharacterLimit', target, limit)

  if isnumber(adjusted) then
    return adjusted
  end

  return limit
end

--- Checks whether a player has to have an active character to be in the world. A player who
-- does is kept hidden and dead, without a HUD or a scoreboard, until they load one, and the
-- main menu opens for them after the intro. Plugins exempt a player through the
-- PlayerNeedsCharacter hook, which is how gamemasters stay in the world without a character.
-- @param target [Player]
-- @return [Boolean false when a PlayerNeedsCharacter handler has returned false, otherwise true]
function Characters.needs_character(target)
  --- Decides whether a player has to have an active character to be in the world. Called on
  -- both realms: on the server when the player spawns, on the client for the local player
  -- when the intro closes and when the HUD and the scoreboard are about to be drawn. The
  -- answer only matters while the player has no active character, or a banned one.
  -- @param target [Player the player in question]
  -- @return [Boolean return false to let the player stay in the world without a character;
  --   nothing to leave the decision to the Characters plugin]
  return hook.Run('PlayerNeedsCharacter', target) != false
end

--- Checks whether a player has as many characters as they may have.
-- On the server the player must have their database record, on the client only the local
-- player can be checked.
-- @param target [Player]
-- @return [Boolean true when the player cannot create another character]
-- @see [Characters.get_limit]
function Characters.limit_reached(target)
  return #target:get_all_characters() >= Characters.get_limit(target)
end

--- Brings a physical description to the form in which it is stored: control characters other
-- than line breaks become spaces, the text is trimmed and its line breaks become ' | '.
-- @param text [String]
-- @return [String]
function Characters.normalize_desc(text)
  local cleaned = text:gsub('\r', ''):gsub('[%z\1-\9\11-\31\127]', ' ')

  return (string_trim(cleaned):gsub('\n', ' | '))
end

--- Returns a random name for a character of a faction, for the random name button of character
-- creation and for a player whose faction starts giving them a name of their own.
-- @param actor [Player the player the name is for]
-- @param faction_id [String ID of the faction of the character, nil without one]
-- @param gender [Number CHAR_GENDER_* value of the character]
-- @return [String the name, nil when there is no name to offer]
function Characters.random_name(actor, faction_id, gender)
  --- Asks for a random name for a character. Called on both realms by
  -- `Characters.random_name`: on the client by character creation, on the server when a
  -- player moves into a faction with names of its own. The Factions plugin answers from the
  -- random_names lists of the faction.
  -- @param actor [Player the player the name is for]
  -- @param faction_id [String ID of the faction of the character, nil without one]
  -- @param gender [Number CHAR_GENDER_* value of the character]
  -- @return [String the name; the first non-nil return wins. Character creation shows no
  --   random name button when no handler returns a name for any gender of the faction]
  return hook.Run('GetRandomCharacterName', actor, faction_id, gender)
end
