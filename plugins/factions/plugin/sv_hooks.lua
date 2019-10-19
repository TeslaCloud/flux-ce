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

function Factions:OnActiveCharacterSet(player, char)
  player:set_nv('faction', char.faction)

  local faction_table = player:get_faction()

  player:SetTeam(faction_table.team_id or 1)
end

function Factions:PostCreateCharacter(player, char, char_data)
  char.faction = char_data.faction or 'player'
  char.rank = char_data.rank or 1
  char.char_class = char_data.char_class or ''
end

function Factions:PlayerRestored(player, record)
  if record.whitelists then
    local whitelists = {}

    for k, v in pairs(record.whitelists) do
      table.insert(whitelists, v.faction_id)
    end

    player:set_nv('whitelists', whitelists)
  end
end

function Factions:CharacterGenderChanged(player, char, new_gender, old_gender)
  Characters.set_model(player, player:get_faction():get_random_model(player))
end

function Factions:PreCreateCharacter(player, data)
  local faction_table = Factions.find_by_id(data.faction)
  
  if faction_table and !string.presence(data.name) then
    -- Try to generate the name if one is not present
    data.name = faction_table:generate_name(player, data.rank or 1)
  end
end

function Factions:PlayerCreateCharacter(player, data)
  if !data.faction then
    return CHAR_ERR_FACTION
  end
end
