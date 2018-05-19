--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

class "CFaction"

function CFaction:CFaction(id)
  self.uniqueID = id:MakeID()
  self.Name = "Unknown Faction"
  self.PrintName = nil
  self.Description = "This faction has no description set!"
  self.PhysDesc = "This faction has no default physical description set!"
  self.Whitelisted = false
  self.DefaultClass = nil
  self.Color = Color(255, 255, 255)
  self.Material = nil
  self.HasName = true
  self.HasDescription = true
  self.HasGender = true
  self.Models = {male = {}, female = {}, universal = {}}
  self.Classes = {}
  self.Ranks = {}
  self.Data = {}
  self.NameTemplate = "{rank} {name}"
  -- You can also use {data:key} to insert data
  -- set via Faction:SetData.
end

function CFaction:GetColor()
  return self.Color
end

function CFaction:GetMaterial()
  return self.Material and util.GetMaterial(self.Material)
end

function CFaction:GetImage()
  return self.Material
end

function CFaction:GetName()
  return self.Name
end

function CFaction:GetData(key)
  return self.Data[key]
end

function CFaction:GetDescription()
  return self.Description
end

function CFaction:AddClass(uniqueID, className, description, color, callback)
  if (!uniqueID) then return end

  self.Classes[uniqueID] = {
    name = className,
    description = description,
    color = color,
    callback = callback
  }
end

function CFaction:AddRank(uniqueID, nameFilter)
  if (!uniqueID) then return end

  if (!nameFilter) then nameFilter = uniqueID end

  table.insert(self.Ranks, {
    uniqueID = uniqueID,
    name = nameFilter
  })
end

function CFaction:GenerateName(player, charName, rank, defaultData)
  defaultData = defaultData or {}

  if (hook.Run("ShouldNameGenerate", player, self, charName, rank, defaultData) == false) then return player:Name() end

  if (isfunction(self.MakeName)) then
    return self:MakeName(player, charName, rank, defaultData) or "John Doe"
  end

  local finalName = self.NameTemplate

  if (finalName:find("{name}")) then
    finalName = finalName:Replace("{name}", charName or "")
  end

  if (finalName:find("{rank}")) then
    for k, v in ipairs(self.Ranks) do
      if (v.uniqueID == rank or k == rank) then
        finalName = finalName:Replace("{rank}", v.name)

        break
      end
    end
  end

  local operators = string.FindAll(finalName, "{[%w]+:[%w]+}")

  for k, v in ipairs(operators) do
    v = v[1]

    if (v:StartWith("{callback:")) then
      local funcName = v:utf8sub(11, v:utf8len() - 1)
      local callback = self[funcName]

      if (isfunction(callback)) then
        finalName = finalName:Replace(v, callback(self, player))
      end
    elseif (v:StartWith("{data:")) then
      local key = v:utf8sub(7, v:utf8len() - 1)
      local data = player:GetCharacterData(key, (defaultData[key] or self.Data[key] or ""))

      if (isstring(data)) then
        finalName = finalName:Replace(v, data)
      end
    end
  end

  return finalName
end

function CFaction:SetData(key, value)
  key = tostring(key)

  if (!key) then return end

  self.Data[key] = tostring(value)
end

function CFaction:OnPlayerEntered(player) end
function CFaction:OnPlayerExited(player) end

function CFaction:Register()
  faction.Register(self.uniqueID, self)
end

function CFaction:__tostring()
  return "Faction ["..self.uniqueID.."]["..self.Name.."]"
end

Faction = CFaction
