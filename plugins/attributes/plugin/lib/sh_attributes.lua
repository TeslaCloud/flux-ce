mod 'Attributes'

local stored = Attributes.stored or {}
Attributes.stored = stored

--- Returns every registered attribute definition.
-- @return [Map attribute definitions keyed by attribute ID]
function Attributes.get_stored()
  return stored
end

--- Returns the definition of a registered attribute.
-- @param id [String attribute ID]
-- @return [AttributeBase the attribute definition, or nil if it is not registered]
function Attributes.find(id)
  return stored[id]
end

--- Returns the registered attribute definitions of a single type.
-- @param type [Number attribute type, ATTRIBUTE_STAT or ATTRIBUTE_SKILL]
-- @return [Map attribute definitions keyed by attribute ID]
function Attributes.get_by_type(type)
  local atts_table = {}

  for k, v in pairs(Attributes.stored) do
    if v.type == type then
      atts_table[k] = v
    end
  end

  return atts_table
end

--- Stores an attribute definition and runs the AttributeRegistered hook. Missing fields get
-- defaults: min 0, max 10, total_progress 100, geometric progression with coefficient 1.2.
-- ```
-- local attribute = AttributeBase.new('lockpicking')
-- attribute.name = 'attribute.lockpicking.name'
-- attribute.type = ATTRIBUTE_SKILL
-- attribute.progression_type = PROGRESSION_ARITHMETIC
-- attribute.boostable = false
--
-- Attributes.register(attribute.attribute_id, attribute)
-- ```
-- @param id [String unique attribute ID; raises an error when it is not a string]
-- @param data [AttributeBase attribute definition; nothing happens when it is nil]
-- @see [AttributeBase#register]
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

--- Includes every file of a folder as an attribute definition. Each file gets a fresh ATTRIBUTE
-- global, an AttributeBase named after the file, that is registered once the file has run.
-- ```
-- -- attributes/sh_strength.lua, registered as 'strength'
-- ATTRIBUTE.name = 'attribute.strength.name'
-- ATTRIBUTE.type = ATTRIBUTE_STAT
-- ATTRIBUTE.max = 20
-- ```
-- @param directory [String folder to include files from]
function Attributes.include_attributes(directory)
  Pipeline.include_folder('attribute', directory)
end

--- Removes the expiry timers of every boost and multiplier on a character's attributes.
-- @param character [Character]
function Attributes.destroy_timers(character)
  if character.attributes then
    for k, v in pairs(character.attributes) do
      for k1, v1 in pairs(v.attribute_boosts) do
        timer.destroy('fl_boost_'..v.id..'_'..v1.expires_at)
      end

      for k1, v1 in pairs(v.attribute_multipliers) do
        timer.destroy('fl_multiplier_'..v.id..'_'..v1.expires_at)
      end
    end
  end
end

do
  local player_meta = FindMetaTable('Player')

  --- Returns the level, progress, boosts and multipliers of every attribute of the player's
  -- character. On the client this is the networked copy and the type argument is ignored.
  -- ```
  -- local attributes = target:get_attributes()
  --
  -- -- attributes.strength = {
  -- --   level = 3, progress = 40,
  -- --   boosts = { { value = 2, expires_at = '2026-01-01T12:00:00Z' } },
  -- --   multipliers = {}
  -- -- }
  -- ```
  -- @param type=nil [Number attribute type to filter by, used on the server only]
  -- @return [Map attribute data keyed by attribute ID, nil on the client until it is networked]
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

  --- Returns the player's level in an attribute and their progress towards the next level.
  -- Active boosts are added to the level unless disabled or the attribute is not boostable.
  -- @param attribute_id [String]
  -- @param no_boost=false [Boolean leave active boosts out of the level]
  -- @return [Number level, Number progress]
  function player_meta:get_attribute(attribute_id, no_boost)
    local attribute_table = Attributes.find(attribute_id)
    local attribute = self:get_attributes()[attribute_id]
    local level = attribute.level or attribute_table.min
    local boost = (!no_boost and attribute_table.boostable != false) and self:get_attribute_boost(attribute_id) or 0

    return level + boost, attribute.progress or 0
  end

  --- Returns the sum of the player's boosts to an attribute that have not expired yet.
  -- @param attribute_id [String]
  -- @return [Number]
  function player_meta:get_attribute_boost(attribute_id)
    local attribute_table = Attributes.find(attribute_id)
    local attribute = self:get_attributes()[attribute_id]
    local boost = 0

    for k, v in pairs(attribute.boosts) do
      if time_from_timestamp(v.expires_at) > os.time() then
        boost = boost + v.value
      end
    end

    if attribute_table.boost_limited then
      boost = math.clamp(level, attribute_table.min, attribute_table.max)
    end

    return boost
  end

  --- Returns the player's combined progress multiplier for an attribute. Every multiplier adds
  -- its value minus one on top of 1, and the result is never lower than 1.
  -- @param attribute_id [String]
  -- @return [Number]
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
    --- Sets the player's level in an attribute, clamped to the attribute's min and max, on the
    -- character and in the networked attributes. Server only.
    -- @param attribute_id [String]
    -- @param level [Number]
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

    --- Raises the player's level in an attribute. Server only.
    -- @param attribute_id [String]
    -- @param amount=1 [Number levels to add]
    function player_meta:increase_attribute(attribute_id, amount)
      amount = amount or 1

      self:set_attribute(attribute_id, self:get_attribute(attribute_id) + amount)
    end

    --- Lowers the player's level in an attribute. Server only.
    -- @param attribute_id [String]
    -- @param amount=1 [Number levels to remove]
    function player_meta:decrease_attribute(attribute_id, amount)
      amount = amount or 1

      self:set_attribute(attribute_id, self:get_attribute(attribute_id) - amount)
    end

    --- Adds progress to an attribute, raising or lowering its level whenever a level threshold is
    -- crossed. Does nothing for attributes with has_progress set. Server only.
    -- ```
    -- -- Scaled by the player's multiplier when the attribute is multipliable.
    -- target:progress_attribute('lockpicking', 15)
    -- -- Always exactly 15.
    -- target:progress_attribute('lockpicking', 15, true)
    -- ```
    -- @param attribute_id [String]
    -- @param amount [Number progress to add, negative to remove]
    -- @param no_multiplier=false [Boolean do not scale the amount by the player's multiplier]
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

    --- Removes progress from an attribute, lowering its level when needed. Server only.
    -- @param attribute_id [String]
    -- @param amount [Number progress to remove]
    -- @see [Player#progress_attribute]
    function player_meta:regress_attribute(attribute_id, amount)
      self:progress_attribute(attribute_id, -amount)
    end

    --- Adds a temporary boost to the player's level in an attribute. The boost is stored on the
    -- character, networked, and removed by a timer when it expires. Server only.
    -- ```
    -- -- Two extra levels of strength for five minutes.
    -- target:boost_attribute('strength', 2, 300)
    -- ```
    -- @param attribute_id [String attribute to boost; ignored when it is not boostable]
    -- @param value [Number levels to add]
    -- @param duration [Number seconds until the boost expires]
    function player_meta:boost_attribute(attribute_id, value, duration)
      local attribute_table = Attributes.find(attribute_id)

      if attribute_table.boostable == false then return end

      for k, v in pairs(self:get_character().attributes) do
        if v.attribute_id == attribute_id then
          local expires_at = to_datetime(os.time() + duration)

          local boost = AttributeBoost.new()
            boost.value = value
            boost.expires_at = expires_at
          table.insert(v.attribute_boosts, boost)

          local timer_id = 'fl_boost_'..v.id..'_'..boost.expires_at

          timer.create(timer_id, duration, 1, function()
            for k1, v1 in pairs(v.attribute_boosts) do
              if v1.expires_at == expires_at then
                v1:destroy()
                table.remove(v.attribute_boosts, k1)

                break
              end
            end

            local attributes = self:get_nv('attributes')
            local boosts = attributes[attribute_id].boosts

            for k1, v1 in pairs(boosts) do
              if v1.expires_at == expires_at then
                v1 = nil

                break
              end
            end

            self:set_nv('attributes', attributes)

            timer.destroy(timer_id)
          end)

          break
        end
      end

      local attributes = self:get_nv('attributes')
        table.insert(attributes[attribute_id].boosts, {
          value = value,
          expires_at = to_datetime(os.time() + duration)
        })
      self:set_nv('attributes', attributes)
    end

    --- Adds a temporary progress multiplier to an attribute of the player. The multiplier is
    -- stored on the character and networked. Server only.
    -- ```
    -- -- Double strength progress for an hour.
    -- target:multiply_attribute('strength', 2, 3600)
    -- ```
    -- @param attribute_id [String attribute to affect; ignored when multipliable is false]
    -- @param value [Number multiplier, 2 doubles the progress gained]
    -- @param duration [Number seconds until the multiplier expires]
    -- @see [Player#get_attribute_multiplier]
    function player_meta:multiply_attribute(attribute_id, value, duration)
      local attribute_table = Attributes.find(attribute_id)

      if attribute_table.multipliable == false then return end

      for k, v in pairs(self:get_character().attributes) do
        if v.attribute_id == attribute_id then
          local multiplier = AttributeMultiplier.new()
            multiplier.value = value
            multiplier.expires_at = to_datetime(os.time() + duration)
          table.insert(v.attribute_multipliers, multiplier)

          local timer_id = 'fl_multiplier_'..v.id..'_'..multiplier.expires_at

          timer.create(timer_id, duration, 1, function()
            for k1, v1 in pairs(v.attribute_multipliers) do
              if v1.expires_at == expires_at then
                v1:destroy()
                table.remove(v.attribute_multipliers, k1)

                break
              end
            end

            local attributes = self:get_nv('attributes')
            local multipliers = attributes[attribute_id].multipliers

            for k1, v1 in pairs(multipliers) do
              if v1.expires_at == expires_at then
                v1 = nil

                break
              end
            end

            self:set_nv('attributes', attributes)

            timer.destroy(timer_id)
          end)

          break
        end
      end

      local attributes = self:get_nv('attributes')
        table.insert(attributes[attribute_id].multipliers, {
          value = value,
          expires_at = to_datetime(os.time() + duration)
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
