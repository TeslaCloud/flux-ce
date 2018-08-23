class "CFaction"

function CFaction:CFaction(id)
  self.id = id:to_id()
  self.name = "Unknown Faction"
  self.print_name = nil
  self.description = "This faction has no description set!"
  self.PhysDesc = "This faction has no default physical description set!"
  self.Whitelisted = false
  self.DefaultClass = nil
  self.color = Color(255, 255, 255)
  self.Material = nil
  self.HasName = true
  self.HasDescription = true
  self.HasGender = true
  self.models = {male = {}, female = {}, universal = {}}
  self.Classes = {}
  self.Ranks = {}
  self.Data = {}
  self.nameTemplate = "{rank} {name}"
  -- You can also use {data:key} to insert data
  -- set via Faction:set_data.
end

function CFaction:GetColor()
  return self.color
end

function CFaction:GetMaterial()
  return self.Material and util.GetMaterial(self.Material)
end

function CFaction:GetImage()
  return self.Material
end

function CFaction:get_name()
  return self.name
end

function CFaction:get_data(key)
  return self.Data[key]
end

function CFaction:get_description()
  return self.description
end

function CFaction:AddClass(id, class_name, description, color, callback)
  if (!id) then return end

  self.Classes[id] = {
    name = class_name,
    description = description,
    color = color,
    callback = callback
  }
end

function CFaction:AddRank(id, nameFilter)
  if (!id) then return end

  if (!nameFilter) then nameFilter = id end

  table.insert(self.Ranks, {
    id = id,
    name = nameFilter
  })
end

function CFaction:GenerateName(player, charName, rank, defaultData)
  defaultData = defaultData or {}

  if (hook.Run("ShouldNameGenerate", player, self, charName, rank, defaultData) == false) then return player:Name() end

  if (isfunction(self.MakeName)) then
    return self:MakeName(player, charName, rank, defaultData) or "John Doe"
  end

  local finalName = self.nameTemplate

  if (finalName:find("{name}")) then
    finalName = finalName:Replace("{name}", charName or "")
  end

  if (finalName:find("{rank}")) then
    for k, v in ipairs(self.Ranks) do
      if (v.id == rank or k == rank) then
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

function CFaction:set_data(key, value)
  key = tostring(key)

  if (!key) then return end

  self.Data[key] = tostring(value)
end

function CFaction:OnPlayerEntered(player) end
function CFaction:OnPlayerExited(player) end

function CFaction:register()
  faction.register(self.id, self)
end

function CFaction:__tostring()
  return "Faction ["..self.id.."]["..self.name.."]"
end

Faction = CFaction
