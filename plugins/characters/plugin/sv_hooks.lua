--- Server side of the Characters plugin: keeps players without a character or with a banned
-- one out of the world, gives bots a species, loads the characters of players who join
-- together with their user record, sends the character list to them, applies a character to
-- its player when it is loaded, saves characters together with the health, armor and ammo of
-- their players, fills in and validates character creation data against the species of the
-- character and remembers which names are taken.

--- Reads the names of all characters from the database, so that `Characters.is_name_taken`
-- also knows the characters of players who are not connected.
function Characters:ActiveRecordReady()
  Character:all():get(function(characters)
    Characters.taken_names = {}

    for _, character in ipairs(characters) do
      Characters.remember_name(character.name)
    end
  end):fetch()
end

--- Loads the characters of a player who joins together with their user record, with the
-- relations that `Characters.preloads` names.
-- @param preloads [Map relations of the user record, changed in place]
function Characters:AdjustPlayerRecordPreloads(preloads)
  preloads.characters = Characters.preloads()
end

--- Gives a bot that joins a random registered species, which stands in for the species of the
-- character that bots do not have.
-- @param actor [Player]
function Characters:PlayerInitialSpawn(actor)
  if !actor:IsBot() then return end

  local species = table.Random(Species.get_list())

  if species then
    actor:set_nv('species', species.species_id)
  end
end

--- Hides, locks and silently kills players who spawn without an active character or with a
-- banned one, unless `Characters.needs_character` exempts them.
-- @param actor [Player]
function Characters:PostPlayerSpawn(actor)
  if (!actor:is_character_loaded() or actor:is_character_banned()) and Characters.needs_character(actor) then
    actor:SetNoDraw(true)
    actor:SetNotSolid(true)
    actor:Lock()

    timer.Simple(0, function()
      if IsValid(actor) then
        actor:KillSilent()
        actor:StripAmmo()
      end
    end)
  end
end

--- Keeps a player whose active character is banned from respawning, and a player who has to
-- have a character (see `Characters.needs_character`) while they have none: loading a
-- character spawns them.
-- @param actor [Player]
-- @return [Boolean false while the active character is banned or a needed character is
--   missing, otherwise nil]
function Characters:PlayerDeathThink(actor)
  if actor:is_character_banned() or (!actor:is_character_loaded() and Characters.needs_character(actor)) then
    return false
  end
end

--- Saves the character of a player who died, unless the character is banned: a banned
-- character has nothing of its player to keep, and `Characters.set_banned` saves it before
-- it kills the player.
-- @param victim [Player]
-- @param _inflictor [Entity]
-- @param _attacker [Entity]
function Characters:PlayerDeath(victim, _inflictor, _attacker)
  if victim:is_character_banned() then return end

  victim:save_character()
end

--- Refuses to let a player switch characters while they are dead or ragdolled.
-- @param actor [Player]
-- @param _character [Character the character the player wants to load]
-- @param _current [Character the active character of the player]
-- @return [Boolean false and String the reason when the switch is refused, otherwise nil]
function Characters:PlayerCanSwitchCharacter(actor, _character, _current)
  if !actor:Alive() then
    return false, 'error.character.switch_dead'
  end

  if isfunction(actor.is_ragdolled) and actor:is_ragdolled() then
    return false, 'error.character.switch_ragdolled'
  end
end

--- Writes the health, armor and reserve ammo of the player into their active character
-- before it is saved. Nothing is written for a banned character, whose player stays dead,
-- or before the saved values have been given to the player.
-- @param owner [Player]
-- @param character [Character the character that is being saved]
function Characters:SaveCharacterData(owner, character)
  if owner:IsBot() or !owner.vitals_restored or tobool(character.banned) then return end

  if owner:get_character() == character then
    Characters.store_vitals(owner, character)
  end
end

--- Saves the disconnecting player's character together with their record. Once that has
-- saved the record, the gamemode does not save it a second time; a player who leaves without
-- a character has their record saved by the gamemode.
-- @param actor [Player]
function Characters:PlayerDisconnected(actor)
  if actor:save_character() then
    actor.should_save_data = false
  end
end

--- Sends the character list to the player as soon as they have initialized, then runs the
-- PostRestoreCharacters hook.
-- @param actor [Player]
function Characters:PlayerRestored(actor)
  local timer_name = 'fl_send_characters_to_'..actor:SteamID()

  timer.Create(timer_name, 0.25, 0, function()
    if IsValid(actor) and actor:has_initialized() then
      Characters.send_to_client(actor)

      --- Called on the server after the character list has been sent to a player who has
      -- joined, which happens once their record is restored and they have initialized.
      -- @param actor [Player]
      hook.Run('PostRestoreCharacters', actor)

      timer.Remove(timer_name)
    end

    if !IsValid(actor) then
      timer.Remove(timer_name)
    end
  end)
end

--- Forwards the PostLoadCharacter hook to the player's client, passing the character ID.
-- @param owner [Player]
-- @param character [Character]
function Characters:PostLoadCharacter(owner, character)
  hook.run_client(owner, 'PostLoadCharacter', character.id)
end

--- Runs the PreLoadCharacter hook, refreshes the display name of the character (see
-- `Characters.refresh_display_name`), spawns the player and applies the character's model,
-- skin, health, armor and ammo, then runs the PostLoadCharacter hook.
-- @param owner [Player]
-- @param character [Character]
function Characters:ActiveCharacterSet(owner, character)
  --- Called on the server when a character that has become the active one is about to be
  -- applied to its player, before the player is spawned and given the model, skin, health,
  -- armor and ammo of the character. The return value is ignored.
  -- @param owner [Player]
  -- @param character [Character]
  hook.Run('PreLoadCharacter', owner, character)

  Characters.refresh_display_name(owner)

  owner:Spawn()
  owner:SetModel(character.model or Characters.default_model)
  owner:SetSkin(character.skin or 0)
  owner:ScreenFade(SCREENFADE.IN, Color('white'), 2, 1)

  Characters.restore_vitals(owner, character)

  --- Called on the server once a loaded character has been applied to its player: the player
  -- has been spawned and given the model, skin, health, armor and ammo of the character. The
  -- Characters plugin forwards the hook to the client of the owner, where handlers receive
  -- only the ID of the character.
  -- @param owner [Player]
  -- @param character [Character]
  hook.Run('PostLoadCharacter', owner, character)
end

--- Cancels the timed action of a player who switches to another character, so that it does
-- not end on the character they switch to, and saves their current character.
-- @param owner [Player]
-- @param _new_char [Character]
-- @param _old_char [Character]
function Characters:PreSwitchCharacter(owner, _new_char, _old_char)
  owner:cancel_timed_action()
  owner:save_character()
end

--- Saves the player's character; called once a minute for every player.
-- @param actor [Player]
function Characters:PlayerOneMinute(actor)
  actor:save_character()
end

--- Saves the active character of every connected player.
function Characters:SaveData()
  for _, client in player.Iterator() do
    client:save_character()
  end
end

--- Fills in what the species of a character that is being created does not let its player
-- choose: a species without names of its own names the character with
-- `Characters.random_name`, or leaves it without a name when none is offered, and a species
-- without descriptions of its own gives it its phys_desc, translated to the language of the
-- player. The Characters plugin counts a replaced name or description as generated.
-- @param actor [Player]
-- @param data [Map character creation data, changed in place]
-- @param _option [Map the creation option the player has chosen]
function Characters:PreCreateCharacter(actor, data, _option)
  local species = Species.find_by_id(data.species)

  if !species then return end

  if !species.has_name then
    local gender = species.has_gender and Characters.creation_gender(data.gender) or CHAR_GENDER_NONE

    data.name = Characters.random_name(actor, species.species_id, gender) or ''
  end

  if !species.has_description then
    data.description = t(species:get_phys_desc() or '', nil, Flux.Lang:get_player_lang(actor))
  end
end

--- Checks the creation data of a character against its species: the species has to be
-- registered (CHAR_ERR_SPECIES), the player must not have as many characters of it as it
-- allows unless `Characters.can_bypass_creation_limits` lets them past the limit
-- (CHAR_ERR_SPECIES_LIMIT), the gender has to fit it, male or female for a species with
-- genders and none for any other (CHAR_ERR_GENDER), and the model has to be one of its models
-- for that gender (CHAR_ERR_MODEL).
-- @param actor [Player]
-- @param data [Map character creation data]
-- @return [Number CHAR_ERR_* code when the data is rejected, otherwise nil]
local function check_species(actor, data)
  local species = Species.find_by_id(isstring(data.species) and data.species or Characters.default_species)

  if !species then
    return CHAR_ERR_SPECIES
  end

  if Characters.species_limit_reached(actor, species.species_id)
  and !Characters.can_bypass_creation_limits(actor, data) then
    return CHAR_ERR_SPECIES_LIMIT
  end

  local genderless = data.gender == CHAR_GENDER_NONE

  if genderless == tobool(species.has_gender) then
    return CHAR_ERR_GENDER
  end

  local gender_name = genderless ? 'universal' : Characters.gender_names[data.gender]

  if !table.HasValue(species:get_gender_models(gender_name), data.model) then
    return CHAR_ERR_MODEL
  end
end

--- Validates character creation data: the presence of the player's database record, the
-- character limit, the length of the name (a generated name only has to be no longer than
-- the limit), the length of the description unless it was generated, gender, model and skin,
-- the species and, unless the name was generated, that no other
-- character has the name. Text that is not valid UTF-8 is rejected.
-- @param actor [Player]
-- @param data [Map character creation data]
-- @return [Number CHAR_ERR_* code when the data is rejected, otherwise nil]
function Characters:PlayerCreateCharacter(actor, data)
  if !istable(actor.record) then
    return CHAR_ERR_RECORD
  end

  if Characters.limit_reached(actor) then
    return CHAR_ERR_LIMIT
  end

  local name_length = isstring(data.name) and utf8.len(data.name)
  local min_name_length = data.name_generated ? 1 : Config.get('characters_min_name_len')

  if !isnumber(name_length) or name_length < min_name_length or
    name_length > Config.get('characters_max_name_len') then
    return CHAR_ERR_NAME
  end

  local desc_length = isstring(data.phys_desc) and utf8.len(data.phys_desc)

  if !isnumber(desc_length) then
    return CHAR_ERR_DESC
  end

  if !data.description_generated and (desc_length < Config.get('characters_min_desc_len') or
    desc_length > Config.get('characters_max_desc_len')) then
    return CHAR_ERR_DESC
  end

  if !isnumber(data.gender) or (data.gender < CHAR_GENDER_MALE or data.gender > CHAR_GENDER_NONE) then
    return CHAR_ERR_GENDER
  end

  if !isstring(data.model) or data.model == '' then
    return CHAR_ERR_MODEL
  end

  local skin = data.skin

  if skin != nil and (!isnumber(skin) or skin < 0 or skin > 255 or skin != math.floor(skin)) then
    return CHAR_ERR_MODEL
  end

  local species_error = check_species(actor, data)

  if species_error then
    return species_error
  end

  if !data.name_generated and Characters.is_name_taken(data.name) then
    return CHAR_ERR_EXISTS
  end
end
