library.new "attributes"

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

function attributes.register(id, data)
  if (!data) then return end

  if (!isstring(id) and !isstring(data.name)) then
    ErrorNoHalt("Attempt to register an attribute without a valid ID!")
    debug.Trace()

    return
  end

  if (!id) then
    id = data.name:to_id()
  end

  fl.dev_print("Registering "..string.lower(data.type)..": "..tostring(id))

  data.attr_id = id
  data.name = data.name or "Unknown Attribute"
  data.description = data.description or "This attribute has no description!"
  data.max = data.max or 100
  data.min = data.min or 0
  data.category = data.category or "#Attribute_Category_Other"
  data.icon = data.icon
  data.type = data.type
  if data.multipliable == nil then data.multipliable = true end
  if data.boostable == nil then data.boostable = true end

  stored[id] = data
end

function attributes.find_by_id(id)
  return stored[id]
end

function attributes.RegisterType(id, globalVar, folder)
  types[id] = globalVar

  plugin.add_extra(id)

  attributes.IncludeType(id, globalVar, folder)

  fl.dev_print("Registering attribute type: ["..id.."] ["..globalVar.."] ["..folder.."]")
end

function attributes.IncludeType(id, globalVar, folder)
  pipeline.register(id, function(id, file_name, pipe)
    _G[globalVar] = Attribute.new(id)

    util.include(file_name)

    if (pipeline.IsAborted()) then _G[globalVar] = nil return end

    _G[globalVar].type = globalVar
    _G[globalVar]:register()
    _G[globalVar] = nil
  end)

  pipeline.include_folder(id, folder)
end

do
  local player_meta = FindMetaTable("Player")

  function player_meta:GetAttributes()
    return self:get_nv("attributes", {})
  end

  function player_meta:GetAttribute(id, bNoBoost)
    local attribute = attributes.find_by_id(id)
    local attsTable = self:GetAttributes()

    if (!attsTable[id]) then
      return attribute.min
    end

    local value = attsTable[id].value

    if (!bNoBoost and attribute.boostable) then
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
      local attribute = attributes.find_by_id(id)

      if (!attsTable[id]) then
        attsTable[id] = {}
      end

      attsTable[id].value = math.Clamp(value, attribute.min, attribute.max)

      self:set_nv("attributes", attsTable)
    end

    function player_meta:IncreaseAttribute(id, value, bNoMultiplier)
      local attribute = attributes.find_by_id(id)
      local attsTable = self:GetAttributes()

      if (!bNoMultiplier) then
        value = value * self:GetAttributeMultiplier(id)

        if (value < 0) then
          value = value / self:GetAttributeMultiplier(id)
        end
      end

      attsTable[id].value = math.Clamp(attsTable[id].value + value, attribute.min, attribute.max)

      self:set_nv("attributes", attsTable)
    end

    function player_meta:DecreaseAttribute(id, value, bNoMultiplier)
      self:IncreaseAttribute(id, -value, bNoMultiplier)
    end

    function player_meta:AttributeMultiplier(id, value, duration)
      local attribute = attributes.find_by_id(id)

      if (!attribute.multipliable) then return end
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

      self:set_nv("attributes", attsTable)
    end

    function player_meta:BoostAttribute(id, value, duration)
      local attribute = attributes.find_by_id(id)

      if (!attribute.multipliable) then return end

      local curTime = CurTime()
      local attsTable = self:GetAttributes()
      local expires = attsTable[id].boostExpires

      attsTable[id].boost = value

      if (expires and expires >= curTime) then
        attsTable[id].boostExpires = expires + time
      else
        attsTable[id].boostExpires = curTime + time
      end

      self:set_nv("attributes", attsTable)
    end
  end
end
