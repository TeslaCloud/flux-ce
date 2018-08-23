library.New "attributes"

local stored = attributes.stored or {}
attributes.stored = stored

local types = attributes.types or {}
attributes.types = types

function attributes.GetStored()
  return stored
end

function attributes.GetAll()
  local attsTable = {}

  for k, v in pairs(stored) do
    attsTable[#attsTable + 1] = k
  end

  return attsTable
end

function attributes.Register(id, data)
  if (!data) then return end

  if (!isstring(id) and !isstring(data.Name)) then
    ErrorNoHalt("Attempt to register an attribute without a valid ID!")
    debug.Trace()

    return
  end

  if (!id) then
    id = data.Name:to_id()
  end

  fl.dev_print("Registering "..string.lower(data.Type)..": "..tostring(id))

  data.id = id
  data.Name = data.Name or "Unknown Attribute"
  data.Description = data.Description or "This attribute has no description!"
  data.Max = data.Max or 100
  data.Min = data.Min or 0
  data.Category = data.Category or "#Attribute_Category_Other"
  data.Icon = data.Icon
  data.Type = data.Type
  data.Multipliable = data.Multipliable or true
  data.Boostable = data.Boostable or true

  stored[id] = data
end

function attributes.FindByID(id)
  return stored[id]
end

function attributes.RegisterType(id, globalVar, folder)
  types[id] = globalVar

  plugin.add_extra(id)

  attributes.IncludeType(id, globalVar, folder)

  fl.dev_print("Registering attribute type: ["..id.."] ["..globalVar.."] ["..folder.."]")
end

function attributes.IncludeType(id, globalVar, folder)
  pipeline.Register(id, function(id, fileName, pipe)
    _G[globalVar] = Attribute(id)

    util.include(fileName)

    if (pipeline.IsAborted()) then _G[globalVar] = nil return end

    _G[globalVar].Type = globalVar
    _G[globalVar]:Register()
    _G[globalVar] = nil
  end)

  pipeline.include_folder(id, folder)
end

do
  local player_meta = FindMetaTable("Player")

  function player_meta:GetAttributes()
    return self:GetNetVar("attributes", {})
  end

  function player_meta:GetAttribute(id, bNoBoost)
    local attribute = attributes.FindByID(id)
    local attsTable = self:GetAttributes()

    if (!attsTable[id]) then
      return attribute.Min
    end

    local value = attsTable[id].value

    if (!bNoBoost and attribute.Boostable) then
      value = value + self:GetAttributeBoost(id)
    end

    return value
  end

  function player_meta:GetAttributeMultiplier(id)
    local attribute = self:GetAttributes()[id]

    if (attribute.multiplierExpires >= CurTime()) then
      return attribute.multiplier or 1
    else
      return 1
    end
  end

  function player_meta:GetAttributeBoost(id)
    local attribute = self:GetAttributes()[id]

    if (attribute.boostExpires >= CurTime()) then
      return attribute.boost or 0
    else
      return 0
    end
  end

  if SERVER then
    function player_meta:SetAttribute(id, value)
      local attsTable = self:GetAttributes()
      local attribute = attributes.FindByID(id)

      if (!attsTable[id]) then
        attsTable[id] = {}
      end

      attsTable[id].value = math.Clamp(value, attribute.Min, attribute.Max)

      self:SetNetVar("attributes", attsTable)
    end

    function player_meta:IncreaseAttribute(id, value, bNoMultiplier)
      local attribute = attributes.FindByID(id)
      local attsTable = self:GetAttributes()

      if (!bNoMultiplier) then
        value = value * self:GetAttributeMultiplier(id)

        if (value < 0) then
          value = value / self:GetAttributeMultiplier(id)
        end
      end

      attsTable[id].value = math.Clamp(attsTable[id].value + value, attribute.Min, attribute.Max)

      self:SetNetVar("attributes", attsTable)
    end

    function player_meta:DecreaseAttribute(id, value, bNoMultiplier)
      self:IncreaseAttribute(id, -value, bNoMultiplier)
    end

    function player_meta:AttributeMultiplier(id, value, duration)
      local attribute = attributes.FindByID(id)

      if (!attribute.Multipliable) then return end
      if (value <= 0) then return end

      local curTime = CurTime()
      local attsTable = self:GetAttributes()
      local expires = attsTable[id].multiplierExpires

      attsTable[id].multiplier = value

      if (expires and expires >= curTime) then
        attsTable[id].multiplierExpires = expires + duration
      else
        attsTable[id].multiplierExpires = curTime + duration
      end

      self:SetNetVar("attributes", attsTable)
    end

    function player_meta:BoostAttribute(id, value, duration)
      local attribute = attributes.FindByID(id)

      if (!attribute.Multipliable) then return end

      local curTime = CurTime()
      local attsTable = self:GetAttributes()
      local expires = attsTable[id].boostExpires

      attsTable[id].boost = value

      if (expires and expires >= curTime) then
        attsTable[id].boostExpires = expires + time
      else
        attsTable[id].boostExpires = curTime + time
      end

      self:SetNetVar("attributes", attsTable)
    end
  end
end
