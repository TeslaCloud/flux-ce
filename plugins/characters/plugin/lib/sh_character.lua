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
--
-- The species side of character creation is here too: the options of its first stage
-- (`Characters.get_creation_options`), the random names (`Characters.random_name`) and the
-- limit of characters per species (`Characters.species_limit_reached`).
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

--- Byte patterns of the invisible characters that names drop: the soft hyphen, the combining
-- grapheme joiner, the Arabic letter mark, the Hangul and Khmer fillers, the Mongolian
-- variation selectors and vowel separator, the zero-width spaces and joiners, the direction
-- marks, embeddings, overrides and isolates, the word joiner and the invisible operators,
-- the variation selectors, the byte order mark, the interlinear annotation characters, the
-- musical formatting characters and the tag characters.
const invisible_name_patterns = {
  '\xC2\xAD',
  '\xCD\x8F',
  '\xD8\x9C',
  '\xE1\x85[\x9F\xA0]',
  '\xE1\x9E[\xB4\xB5]',
  '\xE1\xA0[\x8B-\x8F]',
  '\xE2\x80[\x8B-\x8F\xAA-\xAE]',
  '\xE2\x81[\xA0-\xAF]',
  '\xE3\x85\xA4',
  '\xEF\xB8[\x80-\x8F]',
  '\xEF\xBB\xBF',
  '\xEF\xBE\xA0',
  '\xEF\xBF[\xB9-\xBB]',
  '\xF0\x9D\x85[\xB3-\xBA]',
  '\xF3\xA0[\x80\x81\x84-\x87][\x80-\xBF]'
}

--- Byte patterns of the characters that names turn into plain spaces: the C1 control
-- characters, the no-break space, the Ogham space mark, the typographic spaces, the line and
-- paragraph separators, the narrow no-break space, the medium mathematical space, the blank
-- braille pattern and the ideographic space.
const name_space_patterns = {
  '\xC2[\x80-\xA0]',
  '\xE1\x9A\x80',
  '\xE2\x80[\x80-\x8A\xA8\xA9\xAF]',
  '\xE2\x81\x9F',
  '\xE2\xA0\x80',
  '\xE3\x80\x80'
}

--- Brings a character name to the form in which it is stored: invisible characters such as
-- zero-width spaces, joiners and direction marks are removed, Unicode spaces and control
-- characters become spaces, every run of whitespace becomes a single space and the name is
-- trimmed. Two names that look the same have the same normalized form.
-- @param text [String]
-- @return [String]
function Characters.normalize_name(text)
  for i = 1, #invisible_name_patterns do
    text = text:gsub(invisible_name_patterns[i], '')
  end

  for i = 1, #name_space_patterns do
    text = text:gsub(name_space_patterns[i], ' ')
  end

  return (string_trim((text:gsub('%c', ' '):gsub('%s+', ' '))))
end

--- Turns the gender that the character creation menu sends into a CHAR_GENDER_* value.
-- @param gender [String 'male', 'female' or 'universal']
-- @return [Number CHAR_GENDER_FEMALE for 'female', CHAR_GENDER_NONE for 'universal' and
--   CHAR_GENDER_MALE for anything else]
function Characters.creation_gender(gender)
  if gender == 'female' then
    return CHAR_GENDER_FEMALE
  elseif gender == 'universal' then
    return CHAR_GENDER_NONE
  end

  return CHAR_GENDER_MALE
end

--- Brings a physical description to the form in which it is stored: control characters other
-- than line breaks become spaces, the text is trimmed and its line breaks become ' | '.
-- @param text [String]
-- @return [String]
function Characters.normalize_desc(text)
  local cleaned = text:gsub('\r', ''):gsub('[%z\1-\9\11-\31\127]', ' ')

  return (string_trim(cleaned):gsub('\n', ' | '))
end

--- Returns a random name for a character of a species, for the random name button of
-- character creation and for the characters of a species without names of their own: the name
-- a GetRandomCharacterName handler returns, or else one from `Species:get_random_name`.
-- @param actor [Player the player the name is for]
-- @param species_id [String ID of the species of the character]
-- @param gender [Number CHAR_GENDER_* value of the character]
-- @return [String the name, nil when there is no name to offer]
function Characters.random_name(actor, species_id, gender)
  --- Asks for a random name for a character. Called on both realms by
  -- `Characters.random_name`: on the client by character creation, on the server when a
  -- character of a species without names of its own is created. The species picks a name
  -- itself when no handler returns one.
  -- @param actor [Player the player the name is for]
  -- @param species_id [String ID of the species of the character]
  -- @param gender [Number CHAR_GENDER_* value of the character]
  -- @return [String the name; the first non-nil return wins. Character creation shows no
  --   random name button when neither the handlers nor the species offer a name for any
  --   gender]
  local name = hook.Run('GetRandomCharacterName', actor, species_id, gender)

  if isstring(name) then
    return name
  end

  return Species.find_by_id(species_id)?.:get_random_name(gender)
end

--- Returns how many characters of a species a player has. The server counts the characters
-- of the player's record; a client only knows the characters of the local player.
-- @param target [Player]
-- @param species_id [String]
-- @return [Number]
function Characters.count_species(target, species_id)
  local amount = 0

  for _, character in ipairs(target:get_all_characters()) do
    if character.species == species_id then
      amount += 1
    end
  end

  return amount
end

--- Checks whether a player has as many characters of a species as its max_characters field
-- allows, so that they cannot create another one. On the client only the local player can be
-- checked.
-- @param target [Player]
-- @param species_id [String]
-- @return [Boolean false as well when the species does not limit the characters or is not
--   registered]
-- @see [Characters.count_species]
function Characters.species_limit_reached(target, species_id)
  local species = Species.find_by_id(species_id)
  local maximum = species and species:get_max_characters() or 0

  return maximum > 0 and Characters.count_species(target, species_id) >= maximum
end

--- Checks whether a player may create a character beyond the amount of characters its
-- species allows them, which is what a PlayerCanBypassCreationLimits handler decides. The
-- Factions plugin also offers such a player every whitelisted faction.
-- @param target [Player]
-- @param data [Map creation data on the server; on the client the extra data of the creation
--   screen, nil when it has none]
-- @return [Boolean]
function Characters.can_bypass_creation_limits(target, data)
  --- Decides whether a player may create characters past the limits of character creation:
  -- the amount of characters a species allows them and, with the Factions plugin, the
  -- whitelists of factions. Called on the server when a creation request is checked, and on
  -- the client for the local player when the creation screen builds its options and checks
  -- the chosen one, so a handler that is meant to be seen in the menu has to be shared.
  -- @param target [Player the player who creates the character]
  -- @param data [Map the creation data on the server; the extra data of the creation screen
  --   on the client, nil when it has none]
  -- @return [Boolean return true to let the player create the character regardless of the
  --   limits]
  return hook.Run('PlayerCanBypassCreationLimits', target, data) == true
end

--- Builds the options of the first stage of character creation: one per registered species,
-- in the order of `Species.get_list`, which the AdjustCharacterCreationOptions handlers then
-- add to, remove from and relabel. An option is a Map with `id` (unique among the options),
-- `species` (the species ID of the character), `name` and `description` (texts or language
-- phrases), `image` (material path, optional), `sounds` (List<String> of sounds, one of which
-- plays when the option is picked, optional), `color` (optional) and `data` (Map of fields
-- that choosing the option puts into the creation data; an option that a handler leaves
-- without a `data` table gets an empty one once the handlers have run). The list is built the
-- same way on both realms: the creation screen shows it, and the server builds it again for a
-- creation request and copies `species` and `data` of the chosen option over what the client
-- has sent.
-- @param actor [Player the player who creates the character]
-- @param extra_data=nil [Map creation data on the server; on the client the extra data of
--   the creation screen]
-- @return [List<Map> the options]
function Characters.get_creation_options(actor, extra_data)
  local options = {}

  for _, species in ipairs(Species.get_list()) do
    options[#options + 1] = {
      id = species.species_id,
      species = species.species_id,
      name = species:get_name(),
      description = species:get_description(),
      image = species:get_image(),
      sounds = species.menu_sound,
      data = {}
    }
  end

  --- Lets plugins add, remove and relabel the options of the first stage of character
  -- creation. Called on both realms by `Characters.get_creation_options`, with one option
  -- per species in the list; handlers change the list and its options in place and return
  -- nothing. A handler must give the same answer on both realms, since the server checks a
  -- request against the options it builds itself. The Factions plugin labels the option of
  -- a species with its default faction and adds the whitelisted factions.
  -- ```
  -- function PLUGIN:AdjustCharacterCreationOptions(actor, options, extra_data)
  --   for _, option in ipairs(options) do
  --     if option.species == 'human' then
  --       option.data.starting_city = 'city17'
  --     end
  --   end
  -- end
  -- ```
  -- @param actor [Player the player who creates the character]
  -- @param options [List<Map> the options, see `Characters.get_creation_options`, changed in
  --   place]
  -- @param extra_data [Map creation data on the server; on the client the extra data of the
  --   creation screen, nil when it has none]
  hook.Run('AdjustCharacterCreationOptions', actor, options, extra_data)

  for _, option in ipairs(options) do
    if !istable(option.data) then
      option.data = {}
    end
  end

  return options
end

--- Finds a character creation option by its ID among the options of a player.
-- @param actor [Player the player who creates the character]
-- @param id [String option ID]
-- @param extra_data=nil [Map creation data on the server; on the client the extra data of
--   the creation screen]
-- @return [Map the option, nil when the player has no such option]
-- @see [Characters.get_creation_options]
function Characters.find_creation_option(actor, id, extra_data)
  for _, option in ipairs(Characters.get_creation_options(actor, extra_data)) do
    if option.id == id then
      return option
    end
  end
end
