--- Server side of the Factions plugin: keeps the team, the networked faction and the rank of
-- a player in line with their character, stores the faction on new characters, checks the
-- faction, the whitelist, the gender and the model of a character that is being created
-- against the faction's definition, and networks whitelists. It also enforces the limits of
-- factions and ranks when a character is loaded and the amount of characters a player may
-- have in a faction, and gives the members of a faction their weapons, maximum health and
-- armor, rank model and the feelings of NPCs whenever they spawn or their membership changes.

Cable.check_networked_string('fl_faction_creation_refused')

--- Makes a default description of a faction pass the length check that the Characters
-- plugin applies to the descriptions players write: a text that is too short is padded with
-- spaces and a text that is too long is cut. The result only has to pass the check; the
-- character gets the unchanged description afterwards.
-- @param text [String]
-- @return [String]
local function fit_description(text)
  local min_length = tonumber(Config.get('character_min_desc_len')) or 0
  local max_length = tonumber(Config.get('character_max_desc_len')) or 0
  local length = utf8.len(text)

  if !isnumber(length) then return text end

  if length < min_length then
    return text..string.rep(' ', min_length - length)
  elseif max_length >= min_length and length > max_length then
    return text:utf8sub(1, max_length)
  end

  return text
end

--- Asks the PlayerCanBypassFactionLimit hook whether a player may load a character of a
-- faction or rank that is full.
-- @param actor [Player]
-- @param faction_table [Faction the faction of the character]
-- @param rank_table [Map the rank that is full, nil when it is the faction that is full]
-- @param character [Character the character the player wants to load]
-- @return [Boolean]
local function can_bypass_limit(actor, faction_table, rank_table, character)
  --- Decides whether a player may load a character although its faction, or its rank in
  -- that faction, already has as many members online as the limit allows. Called on the
  -- server when a player asks to load such a character.
  -- @param actor [Player the player who wants to load the character]
  -- @param faction_table [Faction the faction of the character]
  -- @param rank_table [Map the rank that is full, nil when it is the faction that is full]
  -- @param character [Character the character they want to load]
  -- @return [Boolean return true to let the player in regardless of the limit]
  return hook.Run('PlayerCanBypassFactionLimit', actor, faction_table, rank_table, character) == true
end

--- Sets the player's team from their faction, puts bots into a random faction, and gives a
-- member of a faction the maximum health and armor of their faction and rank, filled up.
-- @param actor [Player]
function Factions:PostPlayerSpawn(actor)
  local faction_table = actor:get_faction()

  if faction_table then
    actor:SetTeam(faction_table.team_id or 1)
  end

  if actor:IsBot() then
    if table.Count(self.all()) > 0 then
      local random_faction = table.Random(self.all())

      actor:set_faction(random_faction.faction_id)
    end
  end

  if actor:IsBot() or actor:is_character_loaded() then
    self.apply_vitals(actor, true)
  end
end

--- Gives a spawning player the weapons of their faction and rank on top of the default
-- loadout. This is done on the next tick, because the gamemode strips the weapons of the
-- player and gives the default loadout after the plugin handlers of this hook have run. The
-- record of the weapons given before is dropped, as none of them is left after that.
-- @param actor [Player]
-- @param default_loadout [List<String> weapon classes of the default loadout]
function Factions:PostPlayerLoadout(actor, default_loadout)
  actor.faction_weapons = nil

  timer.Simple(0, function()
    if IsValid(actor) and actor:Alive() then
      self.give_loadout(actor)
    end
  end)
end

--- Makes a spawning player use the model of their rank, if the rank has one and their class
-- does not have a model of its own.
-- @param actor [Player]
-- @return [String model path of the rank, nil to leave the choice of the model to others]
function Factions:PrePlayerSetModel(actor)
  if Classes then
    local class_table = actor:get_class()

    if class_table and class_table:get_model(actor) then return end
  end

  local model = self.get_rank_model(actor)

  if model then
    actor.faction_model = model

    return model
  end
end

--- Networks the faction and the rank of the newly active character and sets the player's
-- team to match. A character whose rank does not exist in its faction is given the default
-- rank. The player then gets the maximum health and armor of the faction and rank (full
-- health and armor if the character had none saved), the model of the rank, and the feelings
-- of NPCs towards the faction. A character whose faction is not registered only loses the
-- rank model and the feelings of NPCs that an earlier character of the player has left.
-- @param owner [Player]
-- @param char [Character]
function Factions:OnActiveCharacterSet(owner, char)
  owner:set_nv('faction', char.faction)

  local faction_table = owner:get_faction()

  if !faction_table then
    self.apply_model(owner)
    self.apply_npc_relations(owner)

    return
  end

  owner:SetTeam(faction_table.team_id or 1)

  local rank = tonumber(char.rank)

  if !rank or !faction_table:get_rank(rank) then
    rank = faction_table:get_default_rank()
  end

  char.rank = rank

  owner:set_nv('rank', rank)

  self.apply_vitals(owner)

  local health = tonumber(char.health)
  local max_armor = faction_table:get_max_armor(rank)

  if !health or health <= 0 then
    owner:SetHealth(owner:GetMaxHealth())
  end

  if max_armor and tonumber(char.armor) == nil then
    owner:SetArmor(max_armor)
  end

  self.apply_model(owner)
  self.apply_npc_relations(owner)
end

--- Copies the faction, rank and class from the creation data to the new character, using
-- the 'player' faction and the default rank of the faction when they are missing. Creation
-- requests of clients never carry a rank or a class (see Factions:PreCreateCharacter), so
-- their characters start at the default rank without a class, unless the on_character_create
-- callback of the faction has set one. A character of a faction that does not let players
-- write a description gets the default description of the faction, and a faction or rank
-- that sets a maximum health or armor makes the character start with them.
-- @param owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data]
function Factions:PostCreateCharacter(owner, char, char_data)
  local faction_table = isstring(char_data.faction) and Factions.find_by_id(char_data.faction)
  local rank = tonumber(char_data.rank)

  if faction_table and (!rank or !faction_table:get_rank(rank)) then
    rank = faction_table:get_default_rank()
  end

  char.faction = char_data.faction or 'player'
  char.rank = rank or 1
  char.char_class = char_data.char_class or ''

  if faction_table then
    local max_health = faction_table:get_max_health(char.rank)
    local max_armor = faction_table:get_max_armor(char.rank)

    if isstring(char_data.default_phys_desc) then
      char.phys_desc = char_data.default_phys_desc
    end

    if max_health then
      char.health = max_health
    end

    if max_armor then
      char.armor = max_armor
    end
  end

  self.send_character_counts(owner)
end

--- Networks the IDs of the factions the player is whitelisted for, and how many characters
-- they have in each faction.
-- @param actor [Player]
-- @param record [User the player's database record]
function Factions:PlayerRestored(actor, record)
  if record.whitelists then
    local whitelists = {}

    for k, v in pairs(record.whitelists) do
      table.insert(whitelists, v.faction_id)
    end

    actor:set_nv('whitelists', whitelists)
  end

  self.send_character_counts(actor)
end

--- Updates the networked amounts of characters per faction of a player who is deleting one
-- of their characters.
-- @param actor [Player]
-- @param id [Number ID of the character]
-- @param character [Character the character that is about to be deleted]
function Factions:OnCharacterDelete(actor, id, character)
  self.send_character_counts(actor, character)
end

--- Makes NPCs forget what the faction of a disconnecting player has made them feel.
-- @param actor [Player]
function Factions:PlayerDisconnected(actor)
  self.reset_npc_relations(actor)
end

--- Makes a newly created NPC feel about the players the way their factions say. This is done
-- on the next tick, once the NPC has spawned and set up its own relationships.
-- @param entity [Entity]
function Factions:OnEntityCreated(entity)
  if IsValid(entity) and entity:IsNPC() then
    timer.Simple(0, function()
      self.setup_npc(entity)
    end)
  end
end

--- Gives the player a random model of their faction that matches the new gender.
-- @param owner [Player]
-- @param char [Character]
-- @param new_gender [Number CHAR_GENDER_* value]
-- @param old_gender [Number CHAR_GENDER_* value]
function Factions:CharacterGenderChanged(owner, char, new_gender, old_gender)
  Characters.set_model(owner, owner:get_faction():get_random_model(owner))
end

--- Keeps the model of the rank on a player whose character model has been changed.
-- @param owner [Player]
-- @param char [Character the active character, nil if the player has none]
-- @param model [String the new model of the character]
-- @param old_model [String the model that was networked before the change]
function Factions:CharacterModelChanged(owner, char, model, old_model)
  self.apply_model(owner)
end

--- Gives the model and the weapons of the rank back to a player whose class has changed:
-- the Classes plugin resets the model and takes the weapons of the old class away, which may
-- be those of the rank as well.
-- @param target [Player]
-- @param class_table [CharacterClass the class the player holds now, nil if they have none]
-- @param old_class [CharacterClass the class the player held before, nil if they had none]
function Factions:OnPlayerClassChanged(target, class_table, old_class)
  self.apply_model(target)

  if target:Alive() then
    self.give_loadout(target)
  end
end

--- Refuses to load a character when its faction or its rank already has as many members
-- online as the limit allows, unless a PlayerCanBypassFactionLimit hook lets the player in.
-- The player themselves is not counted, so switching between two characters of a full
-- faction is possible. A character whose rank does not exist in its faction is checked
-- against the default rank, which it is given when it is loaded.
-- @param actor [Player]
-- @param character [Character the character the player wants to load]
-- @return [Boolean false, String the reason and Map its arguments when the character is
--   refused, otherwise nil]
function Factions:PlayerCanUseCharacter(actor, character)
  local faction_table = isstring(character.faction) and Factions.find_by_id(character.faction)

  if !faction_table then return end

  local faction_id = faction_table.faction_id
  local rank = tonumber(character.rank)

  if !rank or !faction_table:get_rank(rank) then
    rank = faction_table:get_default_rank()
  end

  local rank_table = faction_table:get_rank(rank)
  local lang = Flux.Lang:get_player_lang(actor)

  if Factions.is_full(faction_id, nil, actor) and !can_bypass_limit(actor, faction_table, nil, character) then
    local faction_name = t(faction_table.name, nil, lang)

    return false, 'error.faction.full', { faction = faction_name }
  end

  if rank_table and Factions.is_full(faction_id, rank, actor) and
     !can_bypass_limit(actor, faction_table, rank_table, character) then
    return false, 'error.faction.rank_full', { rank = rank_table.id }
  end
end

--- Cleans up the creation data a client has sent: discards the rank and the class, which a
-- client has no say in, generates a name from the faction's name template when the data has
-- no name or the faction does not let players pick one, and replaces the description with
-- the default description of a faction that does not let players write one.
-- @param actor [Player]
-- @param data [Map character creation data, modified in place]
function Factions:PreCreateCharacter(actor, data)
  data.rank = nil
  data.char_class = nil
  data.default_phys_desc = nil

  local faction_table = isstring(data.faction) and Factions.find_by_id(data.faction)

  if !faction_table then return end

  if !faction_table.has_name or !string.presence(data.name) then
    data.name = faction_table:generate_name(actor, faction_table:get_default_rank())
  end

  if !faction_table.has_description then
    local description = self.get_default_description(faction_table, actor)

    data.default_phys_desc = description
    data.description = fit_description(description)
  end
end

--- Rejects character creation when the chosen faction is not registered or requires a
-- whitelist that the player does not have, when the player already has as many characters
-- of the faction as it allows, when the gender does not fit the faction (a faction with
-- genders needs a male or female character, any other faction a genderless one), when the
-- model is not one of the faction's models for that gender, or when the on_character_create
-- callback of the faction refuses the character.
-- @param actor [Player]
-- @param data [Map character creation data]
-- @return [Number CHAR_ERR_FACTION, CHAR_ERR_FACTION_LIMIT, CHAR_ERR_GENDER, CHAR_ERR_MODEL,
--   CHAR_ERR_FACTION_REFUSED or the code the callback of the faction returned when the data
--   is rejected, otherwise nil]
function Factions:PlayerCreateCharacter(actor, data)
  local faction_table = isstring(data.faction) and Factions.find_by_id(data.faction)

  if !faction_table then
    return CHAR_ERR_FACTION
  end

  if faction_table.whitelisted and !actor:has_whitelist(data.faction) then
    return CHAR_ERR_FACTION
  end

  if Factions.character_limit_reached(actor, data.faction) then
    return CHAR_ERR_FACTION_LIMIT
  end

  local genderless = data.gender == CHAR_GENDER_NONE

  if genderless == tobool(faction_table.has_gender) then
    return CHAR_ERR_GENDER
  end

  local gender_models = faction_table:get_gender_models(
    genderless and 'universal' or data.gender == CHAR_GENDER_FEMALE and 'female' or 'male'
  )

  if !gender_models or !table.HasValue(gender_models, data.model) then
    return CHAR_ERR_MODEL
  end

  local result, reason, arguments = faction_table:on_character_create(actor, data)

  if isnumber(result) and result != CHAR_SUCCESS then
    return result
  elseif result == false then
    if isstring(reason) then
      Cable.send(actor, 'fl_faction_creation_refused', reason, arguments)
    end

    return CHAR_ERR_FACTION_REFUSED
  end
end
