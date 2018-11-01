function Factions:PostPlayerSpawn(player)
  local player_faction = player:GetFaction()

  if player_faction then
    player:SetTeam(player_faction.team_id or 1)

    player:set_nv('name', player_faction:GenerateName(player, player:GetCharacterVar('name', player:name()), player:GetRank()))
  end
end

function Factions:SavePlayerData(player, save_data)
  save_data.whitelists = fl.serialize(player:GetWhitelists())
end

function Factions:OnActiveCharacterSet(player, char)
  player:set_nv('faction', char.faction)
end

function Factions:PostCreateCharacter(player, char_id, char, char_data)
  char.faction = char_data.faction or 'player'
end

function Factions:SaveCharacterData(player, char)
  char.faction = char.faction
end

function Factions:RestoreCharacter(player, char_id, char)
  char.faction = char.faction
  char.char_class = data.char_class or ''
end

function Factions:PlayerRestored(player, record)
  if player:IsBot() then
    if faction.Count() > 0 then
      local random_faction = table.Random(faction.GetAll())

      player:set_nv('faction', random_faction.faction_id)

      if random_faction.has_gender then
        player:set_nv('gender', math.random(CHAR_GENDER_MALE, CHAR_GENDER_FEMALE))
      end

      local faction_models = random_faction.models

      if istable(faction_models) then
        local random_model = 'models/humans/group01/male_01.mdl'
        local universal = faction_models.universal or {}

        if random_faction.has_gender then
          local male = faction_models.male or {}
          local female = faction_models.female or {}

          local gender = player:get_nv('gender', -1)

          if gender == -1 and #universal > 0 then
            random_model = universal[math.random(#universal)]
          elseif gender == CHAR_GENDER_MALE and #male > 0 then
            random_model = male[math.random(#male)]
          elseif gender == CHAR_GENDER_FEMALE and #female > 0 then
            random_model = female[math.random(#female)]
          end
        elseif #universal > 0 then
          random_model = universal[math.random(#universal)]
        end

        player:set_nv('model', random_model)
      end

      player:SetTeam(random_faction.team_id or 1)
    end
  end
end
