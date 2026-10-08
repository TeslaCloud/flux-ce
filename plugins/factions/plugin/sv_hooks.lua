--- Server side of the Factions plugin: keeps the team and the networked faction of a player in
-- line with their character, stores the faction on new characters, checks the faction, the
-- whitelist, the gender and the model of a character that is being created against the
-- faction's definition, and networks whitelists.

--- Sets the player's team from their faction and puts bots into a random faction.
-- @param actor [Player]
function Factions:PostPlayerSpawn(actor)
  local faction_table = actor:get_faction()

  if faction_table then
    actor:SetTeam(faction_table.team_id or 1)
  end

  if actor:IsBot() then
    if table.Count(self.all()) > 0 then
      local faction_table = table.Random(self.all())

      actor:set_faction(faction_table.faction_id)
    end
  end
end

--- Networks the faction of the newly active character and sets the player's team to match.
-- @param owner [Player]
-- @param char [Character]
function Factions:OnActiveCharacterSet(owner, char)
  owner:set_nv('faction', char.faction)

  local faction_table = owner:get_faction()

  owner:SetTeam(faction_table.team_id or 1)
end

--- Copies the faction, rank and class from the creation data to the new character, using
-- the 'player' faction and rank 1 when they are missing. Creation requests of clients never
-- carry a rank or a class (see Factions:PreCreateCharacter), so their characters start at
-- rank 1 without a class.
-- @param owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data]
function Factions:PostCreateCharacter(owner, char, char_data)
  char.faction = char_data.faction or 'player'
  char.rank = char_data.rank or 1
  char.char_class = char_data.char_class or ''
end

--- Networks the IDs of the factions the player is whitelisted for.
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
end

--- Gives the player a random model of their faction that matches the new gender.
-- @param owner [Player]
-- @param char [Character]
-- @param new_gender [Number CHAR_GENDER_* value]
-- @param old_gender [Number CHAR_GENDER_* value]
function Factions:CharacterGenderChanged(owner, char, new_gender, old_gender)
  Characters.set_model(owner, owner:get_faction():get_random_model(owner))
end

--- Cleans up the creation data a client has sent: discards the rank and the class, which a
-- client has no say in, and generates a name from the faction's name template when the data
-- has no name or the faction does not let players pick one.
-- @param actor [Player]
-- @param data [Map character creation data, modified in place]
function Factions:PreCreateCharacter(actor, data)
  data.rank = nil
  data.char_class = nil

  local faction_table = Factions.find_by_id(data.faction)

  if faction_table and (!faction_table.has_name or !string.presence(data.name)) then
    data.name = faction_table:generate_name(actor, 1)
  end
end

--- Rejects character creation when the chosen faction is not registered or requires a
-- whitelist that the player does not have, when the gender does not fit the faction (a
-- faction with genders needs a male or female character, any other faction a genderless
-- one), or when the model is not one of the faction's models for that gender.
-- @param actor [Player]
-- @param data [Map character creation data]
-- @return [Number CHAR_ERR_FACTION, CHAR_ERR_GENDER or CHAR_ERR_MODEL when the data is
--   rejected, otherwise nil]
function Factions:PlayerCreateCharacter(actor, data)
  local faction_table = isstring(data.faction) and Factions.find_by_id(data.faction)

  if !faction_table then
    return CHAR_ERR_FACTION
  end

  if faction_table.whitelisted and !actor:has_whitelist(data.faction) then
    return CHAR_ERR_FACTION
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
end
