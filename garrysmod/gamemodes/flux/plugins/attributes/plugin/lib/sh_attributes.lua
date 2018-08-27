library.new "attributes"

local stored = attributes.stored or {}
attributes.stored = stored

local types = attributes.types or {}
attributes.types = types

function attributes.get_stored()
  return stored
end

function attributes.get_all()
  local atts_table = {}

  for k, v in pairs(stored) do
    atts_table[#atts_table + 1] = k
  end

  return atts_table
end

function attributes.get_by_type(type)
  local atts_table = {}

  for k, v in pairs(attributes.stored) do
    if v.type == type then
      atts_table[k] = v
    end
  end

  return atts_table
end

function attributes.register(id, data)
  if !data then return end

  if !isstring(id) and !isstring(data.name) then
    ErrorNoHalt("Attempt to register an attribute without a valid ID!")
    debug.Trace()

    return
  end

  if !id then
    id = data.name:to_id()
  end

  fl.dev_print("Registering "..string.lower(data.type)..": "..tostring(id))

  data.attr_id = id
  data.name = data.name or "Unknown Attribute"
  data.description = data.description or "This attribute has no description!"
  data.max = data.max or 100
  data.min = data.min or 0
  data.category = data.category or "Attribute_Category_Other"
  data.icon = data.icon
  data.type = data.type
  if data.multipliable == nil then data.multipliable = true end
  if data.boostable == nil then data.boostable = true end

  stored[id] = data
end

function attributes.find_by_id(id)
  id = id:to_id()

  return stored[id]
end

function attributes.register_type(id, global_var, folder)
  types[id] = global_var

  plugin.add_extra(id)

  attributes.include_type(id, global_var, folder)

  fl.dev_print("Registering attribute type: ["..id.."] ["..global_var.."] ["..folder.."]")
end

function attributes.include_type(id, global_var, folder)
  pipeline.register(id, function(id, file_name, pipe)
    _G[global_var] = Attribute.new(id)

    util.include(file_name)

    if pipeline.IsAborted() then _G[global_var] = nil return end

    _G[global_var].type = global_var
    _G[global_var]:register()
    _G[global_var] = nil
  end)

  pipeline.include_folder(id, folder)
end

do
  local player_meta = FindMetaTable("Player")

  function player_meta:get_attributes()
    return self:get_nv("attributes", {})
  end

  function player_meta:get_attribute(id, no_boost)
    local attribute = attributes.find_by_id(id)
    local atts_table = self:get_attributes()

    if !atts_table[id] then
      return attribute.min
    end

    local value = atts_table[id].value

    if !no_boost and attribute.boostable then
      value = value + self:get_attribute_boost(id)
    end

    return value
  end

  function player_meta:get_attribute_multiplier(id)
    local attribute = self:get_attributes()[id]

    if attribute.multiplier_expires >= CurTime() then
      return attribute.multiplier or 1
    else
      return 1
    end
  end

  function player_meta:get_attribute_boost(id)
    local attribute = self:get_attributes()[id]

    if attribute.boost_expires >= CurTime() then
      return attribute.boost or 0
    else
      return 0
    end
  end

  if SERVER then
    function player_meta:set_attribute(id, value)
      local atts_table = self:get_attributes()
      local attribute = attributes.find_by_id(id)

      if !atts_table[id] then
        atts_table[id] = {}
      end

      atts_table[id].value = math.Clamp(value, attribute.min, attribute.max)

      self:set_nv("attributes", atts_table)
    end

    function player_meta:increase_attribute(id, value, no_multiplier)
      local attribute = attributes.find_by_id(id)
      local atts_table = self:get_attributes()

      if !no_multiplier then
        value = value * self:get_attribute_multiplier(id)

        if value < 0 then
          value = value / self:get_attribute_multiplier(id)
        end
      end

      atts_table[id].value = math.Clamp(atts_table[id].value + value, attribute.min, attribute.max)

      self:set_nv("attributes", atts_table)
    end

    function player_meta:decrease_attribute(id, value, no_multiplier)
      self:increase_attribute(id, -value, no_multiplier)
    end

    function player_meta:attribute_multiplier(id, value, duration)
      local attribute = attributes.find_by_id(id)

      if !attribute.multipliable then return end
      if value <= 0 then return end

      local cur_time = CurTime()
      local atts_table = self:GetAttributes()
      local expires = atts_table[id].multiplier_expires

      atts_table[id].multiplier = value

      if expires and expires >= cur_time then
        atts_table[id].multiplier_expires = expires + duration
      else
        atts_table[id].multiplier_expires = cur_time + duration
      end

      self:set_nv("attributes", atts_table)
    end

    function player_meta:BoostAttribute(id, value, duration)
      local attribute = attributes.find_by_id(id)

      if !attribute.multipliable then return end

      local cur_time = CurTime()
      local atts_table = self:get_attributes()
      local expires = atts_table[id].boost_expires

      atts_table[id].boost = value

      if expires and expires >= cur_time then
        atts_table[id].boost_expires = expires + time
      else
        atts_table[id].boost_expires = cur_time + time
      end

      self:set_nv("attributes", atts_table)
    end
  end
end
