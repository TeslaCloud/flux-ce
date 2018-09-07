function flFactions:PostPlayerSpawn(player)
  local playerFaction = player:GetFaction()

  if playerFaction then
    player:SetTeam(playerFaction.team_id or 1)

    player:set_nv("name", playerFaction:GenerateName(player, player:GetCharacterVar("name", player:Name()), player:GetRank()))
  end
end

function flFactions:SavePlayerData(player, saveData)
  saveData.whitelists = fl.serialize(player:GetWhitelists())
end

function flFactions:RestorePlayer(player, result)
  if result.whitelists then
    player:SetWhitelists(fl.deserialize(result.whitelists))
  end
end

function flFactions:OnActiveCharacterSet(player, charData)
  player:set_nv("faction", charData.faction or "player")
end

function flFactions:SaveCharaterData(player, char)
  char.faction = char.faction or "player"
end

function flFactions:RestoreCharacter(player, charID, data)
  local char = character.Get(player, charID)

  if char then
    char.faction = data.faction
    char.class = data.class or ""

    character.Save(player, charID)
  end
end

function flFactions:PlayerRestored(player, record)
  if player:IsBot() then
    if faction.Count() > 0 then
      local randomFaction = table.Random(faction.GetAll())

      player:set_nv("faction", randomFaction.id)

      if randomFaction.has_gender then
        player:set_nv("gender", math.random(CHAR_GENDER_MALE, CHAR_GENDER_FEMALE))
      end

      local factionModels = randomFaction.models

      if istable(factionModels) then
        local randomModel = "models/humans/group01/male_01.mdl"
        local universal = factionModels.universal or {}

        if randomFaction.has_gender then
          local male = factionModels.male or {}
          local female = factionModels.female or {}

          local gender = player:get_nv("gender", -1)

          if gender == -1 and #universal > 0 then
            randomModel = universal[math.random(#universal)]
          elseif gender == CHAR_GENDER_MALE and #male > 0 then
            randomModel = male[math.random(#male)]
          elseif gender == CHAR_GENDER_FEMALE and #female > 0 then
            randomModel = female[math.random(#female)]
          end
        elseif #universal > 0 then
          randomModel = universal[math.random(#universal)]
        end

        player:set_nv("model", randomModel)
      end

      player:SetTeam(randomFaction.team_id or 1)
    end
  end
end
