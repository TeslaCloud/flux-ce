function Factions:PostPlayerSpawn(player)
  local player_faction = player:get_faction()

  if player_faction then
    player:SetTeam(player_faction.team_id or 1)

    player:set_nv('name', player_faction:generate_name(player, player:get_character_var('name', player:name()), player:get_rank()))
  end
end

function Factions:SavePlayerData(player)
  for k, v in pairs(player:get_whitelists()) do
    local whitelist = Whitelist.new()
      whitelist.faction_id = v
    table.insert(player.record.whitelists, whitelist)
  end
end

function Factions:OnActiveCharacterSet(player, char)
  player:set_nv('faction', char.faction)

  local player_faction = player:get_faction()

  player:SetTeam(player_faction.team_id or 1)
end

function Factions:PostCreateCharacter(player, char_id, char, char_data)
  char.faction = char_data.faction or 'player'
end

function Factions:PlayerRestored(player, record)
  if record.whitelists then
    local whitelists = {}

    for k, v in pairs(record.whitelists) do
      table.insert(whitelists, v.faction_id)
    end

    player:set_whitelists(whitelists)
  end

  if player:IsBot() then
    if self.count > 0 then
      local random_faction = table.Random(self.all())

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
