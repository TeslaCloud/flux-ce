library 'Attributes'

local stored = Attributes.stored or {}
local types = Attributes.types or {}
Attributes.stored = stored
Attributes.types = types

function Attributes.get_stored()
  return stored
end

function Attributes.get_id_list()
  local atts_table = {}

  for k, v in pairs(stored) do
    table.insert(atts_table, k)
  end

  return atts_table
end

function Attributes.get_by_type(type)
  local atts_table = {}

  for k, v in pairs(Attributes.stored) do
    if v.type == type then
      atts_table[k] = v
    end
  end

  return atts_table
end

function Attributes.register(id, data)
  if !data then return end

  if !isstring(id) and !isstring(data.name) then
    ErrorNoHalt('Attempt to register an attribute without a valid ID!')
    print_traceback()

    return
  end

  if !id then
    id = data.name:to_id()
  end

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

function Attributes.find_by_id(id)
  return stored[id:to_id()]
end

function Attributes.register_type(id, global_var, folder)
  types[id] = global_var

  Plugin.add_extra(id)

  Attributes.include_type(id, global_var, folder)
end

function Attributes.include_type(id, global_var, folder)
  Pipeline.register(id, function(id, file_name, pipe)
    _G[global_var] = Attribute.new(id)

    require_relative(file_name)

    if Pipeline.is_aborted() then _G[global_var] = nil return end

    _G[global_var].type = global_var
    _G[global_var]:register()
    _G[global_var] = nil
  end)

  Pipeline.include_folder(id, folder)
end

function Attributes.id_from_attr_id(atts_table, attr_id)
  for k, v in pairs(atts_table) do
    if v.attr_id == attr_id then
      return v.id
    end
  end
end

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_attributes()
    --[[
    local char_id = self:get_active_character_id()

    if !self.record.characters or !self.record.characters[char_id] then return {} end

    local atts_table = {}

    for k, v in pairs(self.record.characters[char_id].attributes) do
      atts_table[v.attr_id] = v
    end

    return atts_table
    --]]
    return {}
  end

  function player_meta:get_attribute(id, no_boost)
    --[[
    local attribute = Attributes.find_by_id(id)
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
    --]]
    return 1 -- Remove for now because I need to re-do the database structure for this from scratch....
  end

  function player_meta:get_attribute_multiplier(attr_id)
    --[[
    local char = self:get_character()
    local id = Attributes.id_from_attr_id(char.attributes, attr_id)
    local mult = 1

    if char.attributes then
      for k, v in pairs(char.attributes) do
        if v.id == id then
          if time_from_timestamp(v.expires) >= os.time() then
            mult = mult * v.value
          else
            v:destroy()
            table.remove(char.attribute_multipliers, k)
          end
        end
      end
    end

    return mult
    --]]
    return 1 -- Remove for now because I need to re-do the database structure for this from scratch....
  end

  function player_meta:get_attribute_boost(attr_id)
    --[[
    local char = self:get_character()
    local id = Attributes.id_from_attr_id(char.attributes, attr_id)
    local boost = 0

    if char.attribute_boosts then
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
    end

    return boost
    --]]
    return 0 -- Remove for now because I need to re-do the database structure for this from scratch....
  end

  if SERVER then
    function player_meta:set_attribute(attr_id, value)
      --[[
      local attribute = Attributes.find_by_id(attr_id)
      local atts_table = self:get_character().attributes

      for k, v in pairs(atts_table) do
        if v.attr_id == attr_id then
          v.value = math.Clamp(value, attribute.min, attribute.max)
          break
        end
      end
      --]]
    end

    function player_meta:increase_attribute(attr_id, value, no_multiplier)
      --[[
      local attribute = Attributes.find_by_id(attr_id)
      local atts_table = self:get_attributes()
      local id = Attributes.id_from_attr_id(self:get_character().attributes, attr_id)

      if !no_multiplier and attribute.multipliable then
        if value < 0 then
          value = value / self:get_attribute_multiplier(attr_id)
        else
          value = value * self:get_attribute_multiplier(attr_id)
        end
      end

      self:get_character().attributes[id].value = math.Clamp(atts_table[attr_id].value + value, attribute.min, attribute.max)
      --]]
    end

    function player_meta:decrease_attribute(attr_id, value, no_multiplier)
      --[[
      self:increase_attribute(attr_id, -value, no_multiplier)
      --]]
    end

    function player_meta:attribute_multiplier(attr_id, value, duration)
      --[[
      local attribute = Attributes.find_by_id(attr_id)

      if !attribute.multipliable then return end

      local atts_table = self:get_attributes()

      local multiplier = AttributeMultiplier.new()
        multiplier.value = value
        multiplier.expires = to_datetime(os.time() + duration)
        multiplier.attribute_id = Attributes.id_from_attr_id(atts_table, attr_id)
      self:get_character().attribute_multipliers[multiplier:get_id()] = multiplier
      --]]
    end

    function player_meta:attribute_boost(attr_id, value, duration)
      --[[
      local attribute = Attributes.find_by_id(attr_id)

      if !attribute.boostable then return end

      local atts_table = self:get_attributes()

      local boost = AttributeBoost.new()
        boost.value = value
        boost.expires = to_datetime(os.time() + duration)
        boost.attribute_id = Attributes.id_from_attr_id(atts_table, attr_id)
      self:get_character().attribute_boost[boost:get_id()] = boost
      --]]
    end
  end
end
