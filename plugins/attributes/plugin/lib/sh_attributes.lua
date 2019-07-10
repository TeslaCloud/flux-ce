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
  data.has_progress = data.has_progress or true
  data.total_progress = data.total_progress or 100
  data.progression_type = data.progression_type or LEVELING_GRADUAL
  data.progression_coefficient = data.progression_coefficient or 1.5
  data.hidden = data.hidden or false

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

        attributes_table[attribute_id] = {
          level = v.level,
          progress = v.progress
        }
      end

      return attributes_table
    end
  end

  function player_meta:get_attribute(attribute_id)
    local attribute_table = Attributes.find(attribute_id)
    local attribute = self:get_attributes()[attribute_id]

    return attribute.level or attribute_table.min, attribute.progress or 0
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

    function player_meta:progress_attribute(attribute_id, amount)
      local attribute_table = Attributes.find(attribute_id)
      local level, progress = self:get_attribute(attribute_id)

      if !attribute_table.has_progress or level == attribute_table.max then return end

      local char = self:get_character()
      local total_progress = attribute_table:get_total_progress(level)

      progress = progress + amount

      if progress >= total_progress then
        progress = progress - total_progress

        self:increase_attribute(attribute_id)

        if level + 1 == attribute_table.max then
          progress = 0
        end
      elseif progress < 0 then
        progress = total_progress + progress

        self:decrease_attribute(attribute_id)
      end

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
  end
end

Pipeline.register('attribute', function(id, file_name, pipe)
  ATTRIBUTE = Attribute.new(id)

  require_relative(file_name)

  if Pipeline.is_aborted() then ATTRIBUTE = nil return end

  ATTRIBUTE:register()
  ATTRIBUTE = nil
end)
