library.new 'attributes'

local stored = attributes.stored or {}
attributes.stored = stored

local types = attributes.types or {}
attributes.types = types

function attributes.get_stored()
  return stored
end

function attributes.get_id_list()
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
    ErrorNoHalt('Attempt to register an attribute without a valid ID!')
    debug.Trace()

    return
  end

  if !id then
    id = data.name:to_id()
  end

  fl.dev_print('Registering '..string.lower(data.type)..': '..tostring(id))

  data.attr_id = id
  data.name = data.name or 'Unknown Attribute'
  data.description = data.description or 'This attribute has no description!'
  data.max = data.max or 100
  data.min = data.min or 0
  data.category = data.category or 'Attribute_Category_Other'
  data.icon = data.icon
  data.type = data.type
  data.multipliable = data.multipliable or true
  data.boostable = data.boostable or true

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

  fl.dev_print('Registering attribute type: ['..id..'] ['..global_var..'] ['..folder..']')
end

function attributes.include_type(id, global_var, folder)
  pipeline.register(id, function(id, file_name, pipe)
    _G[global_var] = Attribute.new(id)

    util.include(file_name)

    if pipeline.is_aborted() then _G[global_var] = nil return end

    _G[global_var].type = global_var
    _G[global_var]:register()
    _G[global_var] = nil
  end)

  pipeline.include_folder(id, folder)
end

function attributes.id_from_attr_id(atts_table, attr_id)
  for k, v in pairs(atts_table) do
    if v.attr_id == attr_id then return v.id end
  end
end

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_attributes()
    local atts_table = {}

    for k, v in pairs(self.record.characters[self:GetActiveCharacterID()].attributes) do
      atts_table[v.attr_id] = v
    end

    return atts_table
  end

  function player_meta:get_attribute(id, no_boost)
    local attribute = attributes.find_by_id(id)
    local atts_table = self:get_attributes()

    if !atts_table[id] then
      return attribute.min
    end

    local value = atts_table[id].value

    if !no_boost and attribute.boostable then
      local custom_boosts = {}

      hook.run('GetAttributeBoosts', player, id, custom_boosts)

      value = value + self:get_attribute_boost(id)

      if custom_boosts then
        for k, v in pairs(custom_boosts) do
          value = value + v
        end
      end
    end

    return value
  end

  function player_meta:get_attribute_multiplier(attr_id)
    local char = self:GetCharacter()
    local id = attributes.id_from_attr_id(char.attributes, attr_id)
    local mult = 1

    for k, v in pairs(char.attribute_multipliers) do
      if v.attribute_id == id then
        if time_from_timestamp(v.expires) >= os.time() then
          mult = mult * v.value
        else
          v:destroy()
          table.remove(char.attribute_multipliers, k)
        end
      end
    end

    return mult
  end

  function player_meta:get_attribute_boost(attr_id)
    local char = self:GetCharacter()
    local id = attributes.id_from_attr_id(char.attributes, attr_id)
    local boost = 0

    for k, v in pairs(char.attribute_boosts) do
      if v.attribute_id == id then
        if time_from_timestamp(v.expires) >= os.time() then
          boost = boost + v.value
        else
          v:destroy()
          table.remove(char.attribute_boosts, k)
        end
      end
    end

    return boost
  end

  if SERVER then
    function player_meta:set_attribute(attr_id, value)
      local attribute = attributes.find_by_id(attr_id)
      local atts_table = self:GetCharacter().attributes

      for k, v in pairs(atts_table) do
        if v.attr_id == attr_id then
          v.value = math.Clamp(value, attribute.min, attribute.max)
          v:save()

          break
        end
      end
    end

    function player_meta:increase_attribute(attr_id, value, no_multiplier)
      local attribute = attributes.find_by_id(attr_id)
      local atts_table = self:get_attributes()
      local id = attributes.id_from_attr_id(self:GetCharacter().attributes, attr_id)

      if !no_multiplier and attribute.multipliable then
        if value < 0 then
          value = value / self:get_attribute_multiplier(attr_id)
        else
          value = value * self:get_attribute_multiplier(attr_id)
        end
      end

      self:GetCharacter().attributes[id].value = math.Clamp(atts_table[attr_id].value + value, attribute.min, attribute.max)
    end

    function player_meta:decrease_attribute(attr_id, value, no_multiplier)
      self:increase_attribute(attr_id, -value, no_multiplier)
    end

    function player_meta:attribute_multiplier(attr_id, value, duration)
      local attribute = attributes.find_by_id(attr_id)

      if !attribute.multipliable then return end

      local atts_table = self:get_attributes()

      local multiplier = AttributeMultiplier.new()
      multiplier.value = value
      multiplier.expires = to_datetime(os.time() + duration)
      multiplier.attribute_id = attributes.id_from_attr_id(atts_table, attr_id)

      table.insert(self:GetCharacter().attribute_multipliers, multiplier)

      multiplier:save()
    end

    function player_meta:attribute_boost(attr_id, value, duration)
      local attribute = attributes.find_by_id(attr_id)

      if !attribute.boostable then return end

      local atts_table = self:get_attributes()

      local boost = AttributeBoost.new()
      boost.value = value
      boost.expires = to_datetime(os.time() + duration)
      boost.attribute_id = attributes.id_from_attr_id(atts_table, attr_id)

      table.insert(self:GetCharacter().attribute_boosts, boost)

      boost:save()
    end
  end
end
