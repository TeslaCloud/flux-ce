library 'Attributes'

local stored = Attributes.stored or {}
Attributes.stored = stored

function Attributes.get_stored()
  return stored
end

function Attributes.find(id)
  return stored[id]
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

  if !isstring(id) then
    error_with_traceback('Attempt to register an attribute without a valid ID!')

    return
  end

  data.name = data.name or 'attribute.other.name'
  data.description = data.description or 'attribute.other.desc'
  data.max = data.max or 10
  data.min = data.min or 0
  data.category = data.category or 'attribute.category.other'
  data.icon = data.icon
  data.type = data.type
  data.has_progress = data.has_progress
  data.total_progress = data.total_progress or 100
  data.progression_type = data.progression_type or PROGRESSION_GEOMETRIC
  data.progression_coefficient = data.progression_coefficient or 1.2
  data.hidden = data.hidden
  data.boostable = data.boostable
  data.multipliable = data.multipliable
  data.boost_limited = data.boost_limited

  hook.run('AttributeRegistered', id, data)

  stored[id] = data
end

function Attributes.include_attributes(directory)
  Pipeline.include_folder('attribute', directory)
end

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_attributes(type)
    if CLIENT then
      return self:get_nv('attributes')
    else
      local attributes_table = {}

      for k, v in pairs(self:get_character().attributes) do
        local attribute_id = v.attribute_id
        local attribute_table = Attributes.find(attribute_id)

        if type and v.type != attribute_table.type then continue end

        local attribute = {
          level = v.level,
          progress = v.progress,
          boosts = {},
          multipliers = {}
        }

        for k1, v1 in pairs(v.attribute_boosts) do
          table.insert(attribute.boosts, {
            value = v1.value,
            expires_at = v1.expires_at
          })
        end

        for k1, v1 in pairs(v.attribute_multipliers) do
          table.insert(attribute.multipliers, {
            value = v1.value,
            expires_at = v1.expires_at
          })
        end

        attributes_table[attribute_id] = attribute
      end

      return attributes_table
    end
  end

  function player_meta:get_attribute(attribute_id, no_boost)
    local attribute_table = Attributes.find(attribute_id)
    local attribute = self:get_attributes()[attribute_id]
    local level = attribute.level or attribute_table.min
    local boost = (!no_boost and attribute_table.boostable) and self:get_attribute_boost() or 0

    return level + boost, attribute.progress or 0
  end

  function player_meta:get_attribute_boost(attribute_id)
    local attribute_table = Attributes.find(attribute_id)
    local attribute = self:get_attributes()[attribute_id]
    local boost = 0

    for k, v in pairs(attribute.boosts) do
      boost = boost + v.value
    end

    if attribute_table.boost_limited then
      boost = math.clamp(level, attribute_table.min, attribute_table.max)
    end

    return boost
  end

  function player_meta:get_attribute_multiplier(attribute_id)
    local attribute_table = Attributes.find(attribute_id)
    local attribute = self:get_attributes()[attribute_id]
    local multiplier = 0

    for k, v in pairs(attribute.multipliers) do
      multiplier = multiplier + v.value - 1
    end

    return math.max(multiplier, 0) + 1
  end

  if SERVER then
    function player_meta:set_attribute(attribute_id, level)
      local attribute_table = Attributes.find(attribute_id)
      local char = self:get_character()

      level = math.clamp(level, attribute_table.min, attribute_table.max)

      if char then
        for k, v in pairs(char.attributes) do
          if v.attribute_id == attribute_id then
            v.level = level

            break
          end
        end
      end

      local attributes = self:get_nv('attributes')
        attributes[attribute_id].level = level
      self:set_nv('attributes', attributes)
    end

    function player_meta:increase_attribute(attribute_id, amount)
      amount = amount or 1

      self:set_attribute(attribute_id, self:get_attribute(attribute_id) + amount)
    end

    function player_meta:decrease_attribute(attribute_id, amount)
      amount = amount or 1

      self:set_attribute(attribute_id, self:get_attribute(attribute_id) - amount)
    end

    function player_meta:progress_attribute(attribute_id, amount, no_multiplier)
      local attribute_table = Attributes.find(attribute_id)
      local level, progress = self:get_attribute(attribute_id)

      if attribute_table.has_progress then return end

      if attribute_table.multipliable and !no_multiplier then
        local modifier = self:get_attribute_multiplier(attribute_id)

        if amount < 0 and modifier != 0 then
          modifier = 1 / modifier
        end

        amount = math.round(amount * modifier)
      end

      if amount == 0 then return end

      local total_progress = attribute_table:get_total_progress(level)

      progress = progress + amount

      while (progress >= total_progress and level < attribute_table.max) do
        progress = progress - total_progress

        self:increase_attribute(attribute_id)
        level = level + 1
        total_progress = attribute_table:get_total_progress(level)
      end

      while (progress < 0 and level > attribute_table.min) do
        self:decrease_attribute(attribute_id)
        level = level - 1
        total_progress = attribute_table:get_total_progress(level)

        progress = progress + total_progress
      end

      if level == attribute_table.max or progress < 0 then
        progress = 0
      end

      local char = self:get_character()

      if char then
        for k, v in pairs(char.attributes) do
          if v.attribute_id == attribute_id then
            v.progress = progress

            break
          end
        end
      end

      local attributes = self:get_nv('attributes')
        attributes[attribute_id].progress = progress
      self:set_nv('attributes', attributes)
    end

    function player_meta:regress_attribute(attribute_id, amount)
      self:progress_attribute(attribute_id, -amount)
    end

    function player_meta:boost_attribute(attribute_id, value, duration)
      local attribute_table = Attributes.find(attribute_id)

      if attribute_table.boostable == false then return end

      for k, v in pairs(self:get_character().attributes) do
        if v.attribute_id == attribute_id then
          local boost = AttributeBoost.new()
            boost.value = value
            boost.expires_at = to_datetime(os.time() + duration)
          table.insert(v.attribute_boosts, boost)

          break
        end
      end

      local attributes = self:get_nv('attributes')
        table.insert(attributes[attribute_id].boosts, {
          value = value,
          duration = to_datetime(os.time() + duration)
        })
      self:set_nv('attributes', attributes)
    end

    function player_meta:multiply_attribute(attribute_id, value, duration)
      local attribute_table = Attributes.find(attribute_id)

      if attribute_table.multipliable == false then return end

      for k, v in pairs(self:get_character().attributes) do
        if v.attribute_id == attribute_id then
          local multiply = AttributeMultiplier.new()
            multiply.value = value
            multiply.expires_at = to_datetime(os.time() + duration)
          table.insert(v.attribute_multipliers, multiply)

          break
        end
      end

      local attributes = self:get_nv('attributes')
        table.insert(attributes[attribute_id].multipliers, {
          value = value,
          duration = to_datetime(os.time() + duration)
        })
      self:set_nv('attributes', attributes)
    end
  end
end

Pipeline.register('attribute', function(id, file_name, pipe)
  ATTRIBUTE = AttributeBase.new(id)

  require_relative(file_name)

  if Pipeline.is_aborted() then ATTRIBUTE = nil return end

  ATTRIBUTE:register()
  ATTRIBUTE = nil
end)
