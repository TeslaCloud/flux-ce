library.new 'faction'

local stored = faction.stored or {}
faction.stored = stored

local count = faction.count or 0
faction.count = count

function faction.register(id, data)
  if !id or !data then return end

  data.faction_id = id:to_id() or (data.name and data.name:to_id())
  data.name = data.name or 'Unknown Faction'
  data.description = data.description or 'This faction has no description!'
  data.print_name = data.print_name or data.name or 'Unknown Faction'

  team.SetUp(count + 1, data.name, data.color or Color(255, 255, 255))

  data.team_id = count + 1

  stored[data.faction_id] = data
  count = count + 1
end

function faction.find_by_id(id)
  return stored[id]
end

function faction.GetPlayers(id)
  local players = {}

  for k, v in ipairs(_player.GetAll()) do
    if v:get_faction_id() == id then
      table.insert(players, v)
    end
  end

  return players
end

function faction.Find(name, strict)
  for k, v in pairs(stored) do
    if strict then
      if k:utf8lower() == name:utf8lower() then
        return v
      elseif v.name:utf8lower() == name:utf8lower() then
        return v
      end
    else
      if k:utf8lower():find(name:utf8lower()) then
        return v
      elseif v.name:utf8lower():find(name:utf8lower()) then
        return v
      end
    end
  end

  return false
end

function faction.Count()
  return count
end

function faction.GetAll()
  return stored
end

pipeline.register('faction', function(id, file_name, pipe)
  FACTION = Faction.new(id)

  util.include(file_name)

  FACTION:register() FACTION = nil
end)

function faction.IncludeFactions(directory)
  return pipeline.include_folder('faction', directory)
end

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_faction_id()
    return self:get_nv('faction', 'player')
  end

  function player_meta:SetFaction(id)
    local old_faction = self:GetFaction()
    local faction_table = faction.find_by_id(id)
    local char = self:GetCharacter()

    self:set_nv('name', faction_table:GenerateName(self, self:GetCharacterVar('name', self:name()), 1))
    self:SetRank(1)
    self:SetTeam(faction_table.team_id)
    self:set_nv('faction', id)
    self:SetDefaultFactionModel()

    if char then
      char.faction = id

      character.Save(self, char)
    end

    if old_faction then
      old_faction:OnPlayerExited(self)
    end

    faction_table:OnPlayerEntered(self)

    hook.run('OnPlayerFactionChanged', self, faction_table, old_faction)
  end

  function player_meta:SetDefaultFactionModel()
    local faction_table = self:GetFaction()
    local faction_models = faction_table.models
    local char = self:GetCharacter()

    if istable(faction_models) then
      local player_model = string.GetFileFromFilename(self:GetModel())
      local universal = faction_models.universal or {}
      local model
      local model_table

      if faction_table.has_gender then
        local male = faction_models.male or {}
        local female = faction_models.female or {}
        local gender = self:get_nv('gender', -1)

        if gender == CHAR_GENDER_MALE and #male > 0 then
          model_table = male
        elseif gender == CHAR_GENDER_FEMALE and #female > 0 then
          model_table = female
        end
      elseif #universal > 0 then
        model_table = universal
      end

      if model_table then
        for k, v in pairs(model_table) do
          if string.find(v, player_model) then
            model = v

            break
          end
        end

        if !model then
          model = model_table[math.random(#model_table)]
        end

        character.SetModel(self, self:GetCharacter(), model)
      end
    end
  end

  function player_meta:GetFaction()
    return faction.find_by_id(self:get_faction_id())
  end

  function player_meta:SetRank(rank)
    if isnumber(rank) then
      self:SetCharacterData('Rank', rank)
    elseif isstring(rank) then
      local faction_table = self:GetFaction()

      for k, v in ipairs(faction_table.rank) do
        if string.utf8lower(v.id) == string.utf8lower(rank) then
          self:SetCharacterData('Rank', k)
        end
      end
    end
  end

  function player_meta:GetRank()
    return self:GetCharacterData('Rank', -1)
  end

  function player_meta:IsRank(strRank, strict)
    local faction_table = self:GetFaction()
    local rank = self:GetRank()

    if rank != -1 and faction_table then
      for k, v in ipairs(faction_table.rank) do
        if string.utf8lower(v.id) == string.utf8lower(strRank) then
          return (strict and k == rank) or k <= rank
        end
      end
    end

    return false
  end

  function player_meta:GetWhitelists()
    return self:get_nv('whitelists', {})
  end

  function player_meta:HasWhitelist(name)
    return table.HasValue(self:GetWhitelists(), name)
  end

  if SERVER then
    function player_meta:SetWhitelists(data)
      self:set_nv('whitelists', data)
      self:save_player()
    end

    function player_meta:GiveWhitelist(name)
      local whitelists = self:GetWhitelists()

      if !table.HasValue(whitelists, name) then
        table.insert(whitelists, name)

        self:SetWhitelists(whitelists)
      end
    end

    function player_meta:TakeWhitelist(name)
      local whitelists = self:GetWhitelists()

      for k, v in ipairs(whitelists) do
        if v == name then
          table.remove(whitelists, k)

          break
        end
      end

      self:SetWhitelists(whitelists)
    end
  end
end
