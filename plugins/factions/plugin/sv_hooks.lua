--- Sets the player's team from their faction and puts bots into a random faction.
-- @param player [Player]
function Factions:PostPlayerSpawn(player)
  local faction_table = player:get_faction()

  if faction_table then
    player:SetTeam(faction_table.team_id or 1)
  end

  if player:IsBot() then
    if table.count(self.all()) > 0 then
      local faction_table = table.random(self.all())

      player:set_faction(faction_table.faction_id)
    end
  end
end

--- Networks the faction of the newly active character and sets the player's team to match.
-- @param player [Player]
-- @param char [Character]
function Factions:OnActiveCharacterSet(player, char)
  player:set_nv('faction', char.faction)

  local faction_table = player:get_faction()

  player:SetTeam(faction_table.team_id or 1)
end

--- Copies the faction, rank and class from the creation data to the new character, using
-- the 'player' faction and rank 1 when they are missing.
-- @param player [Player]
-- @param char [Character the character being created]
-- @param char_data [Hash character creation data]
function Factions:PostCreateCharacter(player, char, char_data)
  char.faction = char_data.faction or 'player'
  char.rank = char_data.rank or 1
  char.char_class = char_data.char_class or ''
end

--- Networks the IDs of the factions the player is whitelisted for.
-- @param player [Player]
-- @param record [User the player's database record]
function Factions:PlayerRestored(player, record)
  if record.whitelists then
    local whitelists = {}

    for k, v in pairs(record.whitelists) do
      table.insert(whitelists, v.faction_id)
    end

    player:set_nv('whitelists', whitelists)
  end
end

--- Gives the player a random model of their faction that matches the new gender.
-- @param player [Player]
-- @param char [Character]
-- @param new_gender [Number CHAR_GENDER_* value]
-- @param old_gender [Number CHAR_GENDER_* value]
function Factions:CharacterGenderChanged(player, char, new_gender, old_gender)
  Characters.set_model(player, player:get_faction():get_random_model(player))
end

--- Generates a name from the faction's name template when the creation data has no name.
-- @param player [Player]
-- @param data [Hash character creation data, modified in place]
function Factions:PreCreateCharacter(player, data)
  local faction_table = Factions.find_by_id(data.faction)
  
  if faction_table and !string.presence(data.name) then
    -- Try to generate the name if one is not present
    data.name = faction_table:generate_name(player, data.rank or 1)
  end
end

--- Rejects character creation when no faction was chosen.
-- @param player [Player]
-- @param data [Hash character creation data]
-- @return [Number CHAR_ERR_FACTION when the data has no faction, otherwise nil]
function Factions:PlayerCreateCharacter(player, data)
  if !data.faction then
    return CHAR_ERR_FACTION
  end
end
