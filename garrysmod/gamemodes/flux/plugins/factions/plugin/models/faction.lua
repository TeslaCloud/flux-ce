class 'Faction'

function Faction:init(id)
  if !id then return end

  self.faction_id = id:to_id()
  self.name = "Unknown Faction"
  self.print_name = nil
  self.description = "This faction has no description set!"
  self.phys_desc = "This faction has no default physical description set!"
  self.whitelisted = false
  self.default_class = nil
  self.color = Color(255, 255, 255)
  self.material = nil
  self.has_name = true
  self.has_description = true
  self.has_gender = true
  self.models = {male = {}, female = {}, universal = {}}
  self.classes = {}
  self.rank = {}
  self.data = {}
  self.name_template = "{rank} {name}"
  -- You can also use {data:key} to insert data
  -- set via Faction:set_data.
end

function Faction:GetColor()
  return self.color
end

function Faction:GetMaterial()
  return self.material and util.get_material(self.material)
end

function Faction:GetImage()
  return self.material
end

function Faction:get_name()
  return self.name
end

function Faction:get_data(key)
  return self.data[key]
end

function Faction:get_description()
  return self.description
end

function Faction:AddClass(id, class_name, description, color, callback)
  if (!id) then return end

  self.classes[id] = {
    name = class_name,
    description = description,
    color = color,
    callback = callback
  }
end

function Faction:AddRank(id, nameFilter)
  if (!id) then return end

  if (!nameFilter) then nameFilter = id end

  table.insert(self.rank, {
    id = id,
    name = nameFilter
  })
end

function Faction:GenerateName(player, charName, rank, defaultData)
  defaultData = defaultData or {}

  if (hook.run("ShouldNameGenerate", player, self, charName, rank, defaultData) == false) then return player:Name() end

  if (isfunction(self.MakeName)) then
    return self:MakeName(player, charName, rank, defaultData) or "John Doe"
  end

  local finalName = self.name_template

  if (finalName:find("{name}")) then
    finalName = finalName:Replace("{name}", charName or "")
  end

  if (finalName:find("{rank}")) then
    for k, v in ipairs(self.rank) do
      if (v.id == rank or k == rank) then
        finalName = finalName:Replace("{rank}", v.name)

        break
      end
    end
  end

  local assistants = string.find_all(finalName, "{[%w]+:[%w]+}")

  for k, v in ipairs(assistants) do
    v = v[1]

    if (v:StartWith("{callback:")) then
      local funcName = v:utf8sub(11, v:utf8len() - 1)
      local callback = self[funcName]

      if (isfunction(callback)) then
        finalName = finalName:Replace(v, callback(self, player))
      end
    elseif (v:StartWith("{data:")) then
      local key = v:utf8sub(7, v:utf8len() - 1)
      local data = player:GetCharacterData(key, (defaultData[key] or self.data[key] or ""))

      if (isstring(data)) then
        finalName = finalName:Replace(v, data)
      end
    end
  end

  return finalName
end

function Faction:set_data(key, value)
  key = tostring(key)

  if (!key) then return end

  self.data[key] = tostring(value)
end

function Faction:OnPlayerEntered(player) end
function Faction:OnPlayerExited(player) end

function Faction:register()
  faction.register(self.faction_id, self)
end
