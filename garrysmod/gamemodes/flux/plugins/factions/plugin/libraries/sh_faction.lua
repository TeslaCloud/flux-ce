--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

library.New "faction"

local stored = faction.stored or {}
faction.stored = stored

local count = faction.count or 0
faction.count = count

function faction.Register(id, data)
  if (!id or !data) then return end

  data.id = id:MakeID() or (data.Name and data.Name:MakeID())
  data.Name = data.Name or "Unknown Faction"
  data.Description = data.Description or "This faction has no description!"
  data.PrintName = data.PrintName or data.Name or "Unknown Faction"

  team.SetUp(count + 1, data.Name, data.Color or Color(255, 255, 255))

  data.teamID = count + 1

  stored[id] = data
  count = count + 1
end

function faction.FindByID(id)
  return stored[id]
end

function faction.GetPlayers(id)
  local players = {}

  for k, v in ipairs(_player.GetAll()) do
    if (v:GetFactionID() == id) then
      table.insert(players, v)
    end
  end

  return players
end

function faction.Find(name, bStrict)
  for k, v in pairs(stored) do
    if (bStrict) then
      if (k:utf8lower() == name:utf8lower()) then
        return v
      elseif (v.Name:utf8lower() == name:utf8lower()) then
        return v
      end
    else
      if (k:utf8lower():find(name:utf8lower())) then
        return v
      elseif (v.Name:utf8lower():find(name:utf8lower())) then
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

pipeline.Register("faction", function(id, fileName, pipe)
  FACTION = Faction(id)

  util.Include(fileName)

  FACTION:Register() FACTION = nil
end)

function faction.IncludeFactions(directory)
  return pipeline.IncludeDirectory("faction", directory)
end

do
  local player_meta = FindMetaTable("Player")

  function player_meta:GetFactionID()
    return self:GetNetVar("faction", "player")
  end

  function player_meta:SetFaction(id)
    local oldFaction = self:GetFaction()
    local factionTable = faction.FindByID(id)
    local char = self:GetCharacter()

    self:SetNetVar("name", factionTable:GenerateName(self, self:GetCharacterVar("name", self:Name()), 1))
    self:SetRank(1)
    self:SetTeam(factionTable.teamID)
    self:SetNetVar("faction", id)
    self:SetDefaultFactionModel()

    if (char) then
      char.faction = id

      character.Save(self, char.id)
    end

    if (oldFaction) then
      oldFaction:OnPlayerExited(self)
    end

    factionTable:OnPlayerEntered(self)

    hook.Run("OnPlayerFactionChanged", self, factionTable, oldFaction)
  end

  function player_meta:SetDefaultFactionModel()
    local factionTable = self:GetFaction()
    local factionModels = factionTable.Models
    local char = self:GetCharacter()

    if (istable(factionModels)) then
      local playerModel = string.GetFileFromFilename(self:GetModel())
      local universal = factionModels.universal or {}
      local model
      local modelTable

      if (factionTable.HasGender) then
        local male = factionModels.male or {}
        local female = factionModels.female or {}
        local gender = self:GetNetVar("gender", -1)

        if (gender == CHAR_GENDER_MALE and #male > 0) then
          modelTable = male
        elseif (gender == CHAR_GENDER_FEMALE and #female > 0) then
          modelTable = female
        end
      elseif (#universal > 0) then
        modelTable = universal
      end

      if (modelTable) then
        for k, v in pairs(modelTable) do
          if (string.find(v, playerModel)) then
            model = v

            break
          end
        end

        if (!model) then
          model = modelTable[math.random(#modelTable)]
        end

        character.SetModel(self, self:GetActiveCharacterID(), model)
      end
    end
  end

  function player_meta:GetFaction()
    return faction.FindByID(self:GetFactionID())
  end

  function player_meta:SetRank(rank)
    if (isnumber(rank)) then
      self:SetCharacterData("Rank", rank)
    elseif (isstring(rank)) then
      local factionTable = self:GetFaction()

      for k, v in ipairs(factionTable.Ranks) do
        if (string.utf8lower(v.id) == string.utf8lower(rank)) then
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

    if (rank != -1 and factionTable) then
      for k, v in ipairs(factionTable.Ranks) do
        if (string.utf8lower(v.id) == string.utf8lower(strRank)) then
          return (bStrict and k == rank) or k <= rank
        end
      end
    end

    return false
  end

  function player_meta:GetWhitelists()
    return self:GetNetVar("whitelists", {})
  end

  function player_meta:HasWhitelist(name)
    return table.HasValue(self:GetWhitelists(), name)
  end

  if (SERVER) then
    function player_meta:SetWhitelists(data)
      self:SetNetVar("whitelists", data)
      self:SavePlayer()
    end

    function player_meta:GiveWhitelist(name)
      local whitelists = self:GetWhitelists()

      if (!table.HasValue(whitelists, name)) then
        table.insert(whitelists, name)

        self:SetWhitelists(whitelists)
      end
    end

    function player_meta:TakeWhitelist(name)
      local whitelists = self:GetWhitelists()

      for k, v in ipairs(whitelists) do
        if (v == name) then
          table.remove(whitelists, k)

          break
        end
      end

      self:SetWhitelists(whitelists)
    end
  end
end
