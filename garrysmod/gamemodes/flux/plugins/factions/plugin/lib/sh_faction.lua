library.new "faction"

local stored = faction.stored or {}
faction.stored = stored

local count = faction.count or 0
faction.count = count

function faction.register(id, data)
  if !id or !data then return end

  data.faction_id = id:to_id() or (data.name and data.name:to_id())
  data.name = data.name or "Unknown Faction"
  data.description = data.description or "This faction has no description!"
  data.print_name = data.print_name or data.name or "Unknown Faction"

  team.SetUp(count + 1, data.name, data.color or Color(255, 255, 255))

  data.team_id = count + 1

  stored[id] = data
  count = count + 1
end

function faction.find_by_id(id)
  return stored[id]
end

function faction.GetPlayers(id)
  local players = {}

  for k, v in ipairs(_player.GetAll()) do
    if v:GetFactionID() == id then
      table.insert(players, v)
    end
  end

  return players
end

function faction.Find(name, bStrict)
  for k, v in pairs(stored) do
    if bStrict then
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

pipeline.register("faction", function(id, file_name, pipe)
  FACTION = Faction.new(id)

  util.include(file_name)

  FACTION:register() FACTION = nil
end)

function faction.IncludeFactions(directory)
  return pipeline.include_folder("faction", directory)
end

do
  local player_meta = FindMetaTable("Player")

  function player_meta:GetFactionID()
    return self:get_nv('faction', 'player')
  end

  function player_meta:SetFaction(id)
    local oldFaction = self:GetFaction()
    local factionTable = faction.find_by_id(id)
    local char = self:GetCharacter()

    self:set_nv('name', factionTable:GenerateName(self, self:GetCharacterVar("name", self:Name()), 1))
    self:SetRank(1)
    self:SetTeam(factionTable.team_id)
    self:set_nv('faction', id)
    self:SetDefaultFactionModel()

    if char then
      char.faction = id

      character.Save(self, char)
    end

    if oldFaction then
      oldFaction:OnPlayerExited(self)
    end

    factionTable:OnPlayerEntered(self)

    hook.run("OnPlayerFactionChanged", self, factionTable, oldFaction)
  end

  function player_meta:SetDefaultFactionModel()
    local factionTable = self:GetFaction()
    local factionModels = factionTable.models
    local char = self:GetCharacter()

    if istable(factionModels) then
      local playerModel = string.GetFileFromFilename(self:GetModel())
      local universal = factionModels.universal or {}
      local model
      local modelTable

      if factionTable.has_gender then
        local male = factionModels.male or {}
        local female = factionModels.female or {}
        local gender = self:get_nv('gender', -1)

        if gender == CHAR_GENDER_MALE and #male > 0 then
          modelTable = male
        elseif gender == CHAR_GENDER_FEMALE and #female > 0 then
          modelTable = female
        end
      elseif #universal > 0 then
        modelTable = universal
      end

      if modelTable then
        for k, v in pairs(modelTable) do
          if string.find(v, playerModel) then
            model = v

            break
          end
        end

        if !model then
          model = modelTable[math.random(#modelTable)]
        end

        character.SetModel(self, self:GetActiveCharacterID(), model)
      end
    end
  end

  function player_meta:GetFaction()
    return faction.find_by_id(self:GetFactionID())
  end

  function player_meta:SetRank(rank)
    if isnumber(rank) then
      self:SetCharacterData("Rank", rank)
    elseif isstring(rank) then
      local factionTable = self:GetFaction()

      for k, v in ipairs(factionTable.rank) do
        if string.utf8lower(v.id) == string.utf8lower(rank) then
          self:SetCharacterData("Rank", k)
        end
      end
    end
  end

  function player_meta:GetRank()
    return self:GetCharacterData("Rank", -1)
  end

  function player_meta:IsRank(strRank, bStrict)
    local factionTable = self:GetFaction()
    local rank = self:GetRank()

    if rank != -1 and factionTable then
      for k, v in ipairs(factionTable.rank) do
        if string.utf8lower(v.id) == string.utf8lower(strRank) then
          return (bStrict and k == rank) or k <= rank
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
