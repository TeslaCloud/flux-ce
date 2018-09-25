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

    if pipeline.IsAborted() then _G[global_var] = nil return end

    _G[global_var].type = global_var
    _G[global_var]:register()
    _G[global_var] = nil
  end)

  pipeline.include_folder(id, folder)
end

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_attributes()
    local att_table = {}

    for k, v in pairs(self:GetCharacter().attributes) do
      att_table[v.attr_id] = v
    end

    return att_table
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

  function player_meta:get_attribute_multiplier(id)
    return 1
  end

  function player_meta:get_attribute_boost(id)
    return 0
  end

  if SERVER then
    function player_meta:set_attribute(id, value)
      local attribute = attributes.find_by_id(id)

      self:GetCharacter().attributes.value = math.Clamp(value, attribute.min, attribute.max)
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
    end

    function player_meta:decrease_attribute(id, value, no_multiplier)
      self:increase_attribute(id, -value, no_multiplier)
    end

    function player_meta:attribute_multiplier(id, value, duration)

    end

    function player_meta:attribute_boost(id, value, duration)

    end
  end
end
