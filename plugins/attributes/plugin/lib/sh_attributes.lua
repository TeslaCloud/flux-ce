--- Registry of the attribute definitions, together with the player methods that read and
-- change the attributes of a player's character.
-- Definitions are `AttributeBase` objects registered with `Attributes.register`, usually
-- by `Attributes.include_attributes` loading the files of a plugin's `attributes` folder.
--
-- What a character has of an attribute is kept in an `Attribute` record: a level, a progress
-- value, and any number of boosts and progress multipliers. A boost or a multiplier may
-- carry an identifier, which lets the code that gave it replace or remove it later, and may
-- have no expiry, in which case it stays until it is removed. The server networks the
-- attributes of a player to that player alone, in the private 'attributes' networked
-- variable, which the getters read on the client.

mod 'Attributes'

local istable = istable
local tonumber = tonumber
local tostring = tostring
local math_clamp = math.clamp
local math_max = math.max
local math_round = math.round
local os_time = os.time

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
-- @param attribute_type [Number attribute type, ATTRIBUTE_STAT or ATTRIBUTE_SKILL]
-- @return [Map attribute definitions keyed by attribute ID]
function Attributes.get_by_type(attribute_type)
  local atts_table = {}

  for k, v in pairs(stored) do
    if v.type == attribute_type then
      atts_table[k] = v
    end
  end

  return atts_table
end

--- Stores an attribute definition and runs the AttributeRegistered hook. Missing fields get
-- defaults: min 0, max 10, default equal to min, total_progress 100, geometric progression
-- with coefficient 1.2.
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
  data.default = math_clamp(tonumber(data.default) or data.min, data.min, data.max)
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

  --- Called on both realms when an attribute definition is registered, after its missing
  -- fields have been given their defaults and before it is stored. A handler may change the
  -- definition.
  -- @param id [String Attribute ID]
  -- @param data [AttributeBase The attribute definition]
  hook.Run('AttributeRegistered', id, data)

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

--- Adds up the boosts in the data of an attribute. If the attribute has boost_limited set,
-- the sum is cut down so that the level together with the boosts stays between the
-- attribute's min and max.
-- @param attribute_table [AttributeBase attribute definition]
-- @param attribute [Map data of the attribute as `Player:get_attribute_data` returns it;
--   its level and boosts are used]
-- @return [Number]
function Attributes.sum_boosts(attribute_table, attribute)
  local boost = 0
  local boosts = attribute.boosts

  if boosts then
    for k, v in pairs(boosts) do
      boost = boost + (tonumber(v.value) or 0)
    end
  end

  if attribute_table.boost_limited then
    local level = attribute.level or attribute_table.default

    boost = math_clamp(level + boost, attribute_table.min, attribute_table.max) - level
  end

  return boost
end

--- Checks whether an attribute is shown to a player in the Attributes tab. An attribute with
-- its hidden field set is never shown; any other can be hidden with the IsAttributeVisible
-- hook.
-- @param attribute [AttributeBase attribute definition]
-- @param target [Player player whose attributes are being shown]
-- @return [Boolean]
function Attributes.is_visible(attribute, target)
  if !attribute or attribute.hidden then return false end

  --- Lets plugins hide an attribute from a player, for example one that the faction of the
  -- player has no use for. Called on the client for every registered attribute that does
  -- not have its hidden field set, when the tab menu is opened and twice a second while the
  -- Attributes tab is open, so that the tab follows a changed answer.
  -- @param target [Player The player whose attributes are being shown, the local player]
  -- @param attribute [AttributeBase The attribute definition]
  -- @return [Boolean Return false to hide the attribute]
  return hook.Run('IsAttributeVisible', target, attribute) != false
end

if SERVER then
  --- Returns the active character of a player, if they have one.
  -- @param target [Player]
  -- @return [Character/Map the character record, or the stand-in table of a bot; nil if the
  --   player is not valid or has no active character]
  local function get_character(target)
    if !IsValid(target) or !target:is_character_loaded() then return end

    return target:get_character()
  end

  --- Returns the Attribute records of a player's active character.
  -- @param target [Player]
  -- @return [List<Attribute> records; empty if the player has no character that keeps them]
  local function get_records(target)
    local character = get_character(target)

    return istable(character) and istable(character.attributes) and character.attributes or {}
  end

  --- Returns the time at which a boost or multiplier record expires.
  -- @param modifier [AttributeBoost/AttributeMultiplier]
  -- @return [Number/Boolean unix timestamp, 0 if the stored time cannot be read, or false
  --   if the record has no expiry]
  local function get_expiry(modifier)
    local expires_at = modifier.expires_at

    if expires_at == nil or expires_at == '' or expires_at == 'NULL' then
      return false
    end

    return time_from_timestamp(expires_at) or 0
  end

  --- Deletes a boost or multiplier record from the database. A record that has never been
  -- saved has nothing to delete, and one that is being inserted is deleted once the
  -- database has given it an ID.
  -- @param modifier [AttributeBoost/AttributeMultiplier]
  local function destroy_record(modifier)
    if modifier.id then
      modifier:destroy()
    elseif modifier.fetched then
      modifier.after_create = function(obj)
        obj:destroy()
      end
    end
  end

  --- Removes boost or multiplier records from a list and deletes them from the database.
  -- @param modifiers [List<AttributeBoost/AttributeMultiplier> records of one attribute]
  -- @param identifier=nil [String only remove the records with this identifier, which has
  --   to be a string already]
  -- @param before=nil [Number only remove the records that expire at this unix time or
  --   earlier]
  -- @return [Number amount of records removed]
  local function remove_modifiers(modifiers, identifier, before)
    local removed = 0

    for i = #modifiers, 1, -1 do
      local modifier = modifiers[i]
      local expiry = get_expiry(modifier)

      local has_identifier = identifier == nil or
        (modifier.identifier != nil and tostring(modifier.identifier) == identifier)

      if has_identifier and (before == nil or (expiry and expiry <= before)) then
        table.remove(modifiers, i)
        destroy_record(modifier)

        removed = removed + 1
      end
    end

    return removed
  end

  --- Converts the boost or multiplier records of an attribute to the tables that are
  -- networked, leaving out the ones that have expired.
  -- @param modifiers [List<AttributeBoost/AttributeMultiplier> records of one attribute]
  -- @param unix_time [Number current os.time()]
  -- @param cur_time [Number current CurTime()]
  -- @return [List<Map> networkable tables, Number earliest unix time at which a record of
  --   the list expires or has expired; nil if none has an expiry]
  local function modifiers_to_networkable(modifiers, unix_time, cur_time)
    local entries = {}
    local earliest

    for k, v in ipairs(modifiers) do
      local expiry = get_expiry(v)

      if expiry and (!earliest or expiry < earliest) then
        earliest = expiry
      end

      if !expiry or expiry > unix_time then
        entries[#entries + 1] = {
          value = tonumber(v.value) or 0,
          id = v.identifier != nil and tostring(v.identifier) or nil,
          expires_at = expiry and v.expires_at or nil,
          end_time = expiry and cur_time + (expiry - unix_time) or nil
        }
      end
    end

    return entries, earliest
  end

  --- Converts an Attribute record to the table that is networked.
  -- @param record [Attribute]
  -- @param attribute_table [AttributeBase definition of the record's attribute]
  -- @param unix_time [Number current os.time()]
  -- @param cur_time [Number current CurTime()]
  -- @return [Map level, progress, boosts and multipliers, Number earliest unix time at which
  --   a boost or multiplier of the record expires or has expired; nil if none has an expiry]
  local function record_to_networkable(record, attribute_table, unix_time, cur_time)
    local boosts, boost_expiry = modifiers_to_networkable(record.attribute_boosts or {}, unix_time, cur_time)
    local multipliers, multiplier_expiry =
      modifiers_to_networkable(record.attribute_multipliers or {}, unix_time, cur_time)
    local earliest = boost_expiry

    if multiplier_expiry and (!earliest or multiplier_expiry < earliest) then
      earliest = multiplier_expiry
    end

    return {
      level = tonumber(record.level) or attribute_table.default,
      progress = tonumber(record.progress) or 0,
      boosts = boosts,
      multipliers = multipliers
    }, earliest
  end

  --- Finds the record that a character keeps for an attribute.
  -- @param character [Character character record; anything else finds nothing]
  -- @param attribute_id [String]
  -- @return [Attribute the record, or nil if the character has none]
  function Attributes.get_record(character, attribute_id)
    if !istable(character) or !istable(character.attributes) then return end

    for k, v in ipairs(character.attributes) do
      if v.attribute_id == attribute_id then
        return v
      end
    end
  end

  --- Returns the level, progress, boosts and multipliers of one attribute of a player's
  -- character, in the form that is networked.
  -- @param target [Player]
  -- @param attribute_id [String]
  -- @return [Map attribute data, or nil if the attribute is not registered or the player's
  --   character has no record for it]
  function Attributes.get_data(target, attribute_id)
    local attribute_table = stored[attribute_id]
    local record = attribute_table and Attributes.get_record(get_character(target), attribute_id)

    if !record then return end

    local data = record_to_networkable(record, attribute_table, os_time(), CurTime())

    return data
  end

  --- Gives a character a record for every registered attribute it has none for. A new
  -- record starts at the given level, rounded down and kept between the attribute's min and
  -- max, or at the attribute's default level, and with no progress. The records are saved
  -- with the character.
  -- @param character [Character]
  -- @param levels=nil [Map starting levels keyed by attribute ID]
  -- @return [Number amount of records added]
  function Attributes.create_records(character, levels)
    if !istable(character) or !istable(character.attributes) then return 0 end

    levels = istable(levels) and levels or {}

    local added = 0

    for k, v in pairs(stored) do
      if !Attributes.get_record(character, k) then
        local level = tonumber(levels[k])

        if !level or level != level then
          level = v.default
        end

        local attribute = Attribute.new()
          attribute.attribute_id = k
          attribute.level = math_clamp(math.floor(level), v.min, v.max)
          attribute.progress = 0
        table.insert(character.attributes, attribute)

        added = added + 1
      end
    end

    return added
  end

  --- Builds the table that is networked for a player: the level, progress, boosts and
  -- multipliers of every registered attribute their character has a record for.
  -- @param target [Player]
  -- @param attribute_type=nil [Number only include the attributes of this type]
  -- @return [Map attribute data keyed by attribute ID, Number earliest unix time at which a
  --   boost or multiplier of the character expires or has expired; nil if none has an expiry]
  function Attributes.to_networkable(target, attribute_type)
    local attributes = {}
    local unix_time, cur_time = os_time(), CurTime()
    local earliest

    for k, v in ipairs(get_records(target)) do
      local attribute_table = stored[v.attribute_id]

      if attribute_table and (attribute_type == nil or attribute_table.type == attribute_type) then
        local entry, expiry = record_to_networkable(v, attribute_table, unix_time, cur_time)

        if expiry and (!earliest or expiry < earliest) then
          earliest = expiry
        end

        attributes[v.attribute_id] = entry
      end
    end

    return attributes, earliest
  end

  --- Networks the attributes of a player's character to that player again and notes when
  -- the next of its boosts and multipliers expires. Called after every change the plugin
  -- makes; call it yourself after changing the records directly.
  -- @param target [Player]
  function Attributes.sync(target)
    if !IsValid(target) then return end

    local attributes, earliest = Attributes.to_networkable(target)

    target.attribute_expiry = earliest
    target:set_private_nv('attributes', attributes)
  end

  --- Removes the boosts and multipliers of a player's character that have expired, deleting
  -- their records. Does not network the change, see `Attributes.sync`.
  -- @param target [Player]
  -- @return [Number amount of boosts and multipliers removed]
  function Attributes.remove_expired(target)
    local unix_time = os_time()
    local removed = 0

    for k, v in ipairs(get_records(target)) do
      removed = removed + remove_modifiers(v.attribute_boosts or {}, nil, unix_time)
      removed = removed + remove_modifiers(v.attribute_multipliers or {}, nil, unix_time)
    end

    return removed
  end

  --- Sets the level and the progress of an attribute of a player's character, networks the
  -- attributes and runs the PlayerAttributeChanged hook. Nothing happens if neither value
  -- changes or the character has no record for the attribute.
  -- @param target [Player]
  -- @param attribute_id [String]
  -- @param level=nil [Number new level, rounded and kept between the attribute's min and
  --   max; the level stays as it is if nil]
  -- @param progress=nil [Number new progress, never lower than 0; the progress stays as it
  --   is if nil]
  -- @return [Boolean true if the level or the progress has changed]
  function Attributes.update(target, attribute_id, level, progress)
    local attribute_table = stored[attribute_id]
    local record = attribute_table and Attributes.get_record(get_character(target), attribute_id)

    if !record then return false end

    local old_level = tonumber(record.level) or attribute_table.default
    local old_progress = tonumber(record.progress) or 0

    level = tonumber(level) or old_level
    progress = tonumber(progress) or old_progress

    if level != level or progress != progress then return false end

    level = math_clamp(math_round(level), attribute_table.min, attribute_table.max)
    progress = math_max(progress, 0)

    if level == old_level and progress == old_progress then return false end

    record.level = level
    record.progress = progress

    Attributes.sync(target)

    --- Called on the server after the level or the progress of an attribute of a player's
    -- character has changed and the change has been networked, however it came about:
    -- through `Player:set_attribute`, `Player:progress_attribute` and the methods built on
    -- them, or the staff commands. A call of `Player:progress_attribute` that moves the
    -- attribute over several levels runs the hook once. Boosts do not run it.
    -- @param actor [Player The player whose character the attribute belongs to]
    -- @param attribute_id [String Attribute ID]
    -- @param level [Number New level, without boosts]
    -- @param progress [Number New progress toward the next level]
    -- @param old_level [Number Level before the change]
    -- @param old_progress [Number Progress before the change]
    hook.Run('PlayerAttributeChanged', target, attribute_id, level, progress, old_level, old_progress)

    return true
  end

  --- Gives a player's character a boost or a multiplier and networks the attributes. One
  -- that carries an identifier replaces those of the same attribute with that identifier.
  -- This is what `Player:boost_attribute` and `Player:multiply_attribute` are built on; it
  -- does not check whether the attribute is boostable or multipliable.
  -- @param target [Player]
  -- @param attribute_id [String]
  -- @param list_key [String field of the Attribute record that holds the records]
  -- @param model [ActiveRecord::Base class of the records, AttributeBoost or
  --   AttributeMultiplier]
  -- @param value [Number]
  -- @param duration=nil [Number seconds until it expires; it never expires if this is nil
  --   or not above 0]
  -- @param identifier=nil [Any identifier, converted to a string]
  -- @return [AttributeBoost/AttributeMultiplier the new record, or nil if the value is not a
  --   number or the character has no record for the attribute]
  function Attributes.add_modifier(target, attribute_id, list_key, model, value, duration, identifier)
    local record = Attributes.get_record(get_character(target), attribute_id)

    value = tonumber(value)
    duration = tonumber(duration)

    if !record or !value or value != value then return end

    record[list_key] = record[list_key] or {}

    if identifier != nil then
      identifier = tostring(identifier)

      remove_modifiers(record[list_key], identifier)
    end

    local modifier = model.new()
      modifier.value = value
      modifier.identifier = identifier

      if duration and duration > 0 then
        modifier.expires_at = to_datetime(os_time() + math.ceil(duration))
      end
    table.insert(record[list_key], modifier)

    Attributes.sync(target)

    return modifier
  end

  --- Removes boosts or multipliers from a player's character and networks the attributes
  -- if any were removed. This is what `Player:remove_attribute_boosts` and
  -- `Player:remove_attribute_multipliers` are built on.
  -- @param target [Player]
  -- @param list_key [String field of the Attribute record that holds the records]
  -- @param attribute_id=nil [String only remove from this attribute]
  -- @param identifier=nil [Any only remove the ones with this identifier]
  -- @return [Number amount removed]
  function Attributes.clear_modifiers(target, list_key, attribute_id, identifier)
    local removed = 0

    if identifier != nil then
      identifier = tostring(identifier)
    end

    for k, v in ipairs(get_records(target)) do
      if attribute_id == nil or v.attribute_id == attribute_id then
        removed = removed + remove_modifiers(v[list_key] or {}, identifier)
      end
    end

    if removed > 0 then
      Attributes.sync(target)
    end

    return removed
  end
end

do
  local player_meta = FindMetaTable('Player')

  --- Returns the level, progress, boosts and multipliers of every attribute of the player's
  -- character. On the client this is what the server has networked, which it does for the
  -- local player alone: any other player has no attributes there. A boost or multiplier
  -- has a value, the identifier it was given (`id`), the time it expires at as a date-time
  -- string (`expires_at`) and as a CurTime (`end_time`); the last three are nil when not set.
  -- ```
  -- local attributes = target:get_attributes()
  --
  -- -- attributes.strength = {
  -- --   level = 3, progress = 40,
  -- --   boosts = {
  -- --     { value = 2, expires_at = '2026-01-01T12:00:00Z', end_time = 1520 },
  -- --     { value = -1, id = 'drunk' }
  -- --   },
  -- --   multipliers = {}
  -- -- }
  -- ```
  -- @param attribute_type=nil [Number attribute type to filter by]
  -- @return [Map attribute data keyed by attribute ID; empty if the player has no character
  --   or, on the client, nothing has been networked yet or the player is not the local one]
  function player_meta:get_attributes(attribute_type)
    if SERVER then
      local attributes = Attributes.to_networkable(self, attribute_type)

      return attributes
    end

    local attributes = self:get_nv('attributes') or {}

    if attribute_type == nil then
      return attributes
    end

    local filtered = {}

    for k, v in pairs(attributes) do
      local attribute_table = stored[k]

      if attribute_table and attribute_table.type == attribute_type then
        filtered[k] = v
      end
    end

    return filtered
  end

  --- Returns the level, progress, boosts and multipliers of one attribute of the player's
  -- character, in the form `Player:get_attributes` describes.
  -- @param attribute_id [String]
  -- @return [Map attribute data, or nil if the attribute is not registered or the player's
  --   character has no data for it]
  function player_meta:get_attribute_data(attribute_id)
    local attribute_table = stored[attribute_id]

    if !attribute_table then return end

    if CLIENT then
      local attributes = self:get_nv('attributes')

      return attributes and attributes[attribute_id]
    end

    return Attributes.get_data(self, attribute_id)
  end

  --- Returns the player's level in an attribute and their progress toward the next level.
  -- Active boosts are added to the level unless disabled or the attribute is not boostable.
  -- A player whose character has no data for the attribute, such as a bot, is at the
  -- attribute's default level.
  -- @param attribute_id [String]
  -- @param no_boost=false [Boolean leave active boosts out of the level]
  -- @return [Number level, Number progress; 0 and 0 if the attribute is not registered]
  function player_meta:get_attribute(attribute_id, no_boost)
    local attribute_table = stored[attribute_id]

    if !attribute_table then return 0, 0 end

    local attribute = self:get_attribute_data(attribute_id)

    if !attribute then
      return attribute_table.default, 0
    end

    local level = attribute.level or attribute_table.default
    local boost = 0

    if !no_boost and attribute_table.boostable != false then
      boost = Attributes.sum_boosts(attribute_table, attribute)
    end

    return level + boost, attribute.progress or 0
  end

  --- Returns the sum of the player's active boosts to an attribute. The server leaves an
  -- expired boost out and takes it out of the networked data, so on the client every
  -- networked boost counts. If the attribute has boost_limited set, the sum is cut down so
  -- that the level together with the boost stays between the attribute's min and max.
  -- @param attribute_id [String]
  -- @return [Number]
  function player_meta:get_attribute_boost(attribute_id)
    local attribute_table = stored[attribute_id]
    local attribute = attribute_table and self:get_attribute_data(attribute_id)

    if !attribute then return 0 end

    return Attributes.sum_boosts(attribute_table, attribute)
  end

  --- Returns the player's active boosts to an attribute.
  -- @param attribute_id [String]
  -- @return [List<Map> boosts, each with value and, when set, id, expires_at and end_time]
  -- @see [Player#get_attributes]
  function player_meta:get_attribute_boosts(attribute_id)
    local attribute = self:get_attribute_data(attribute_id)

    return attribute and attribute.boosts or {}
  end

  --- Checks whether the player has an active boost with the given identifier.
  -- @param attribute_id [String]
  -- @param identifier [Any identifier the boost was given, compared as a string]
  -- @return [Boolean]
  function player_meta:has_attribute_boost(attribute_id, identifier)
    if identifier == nil then return false end

    identifier = tostring(identifier)

    for k, v in pairs(self:get_attribute_boosts(attribute_id)) do
      if v.id == identifier then
        return true
      end
    end

    return false
  end

  --- Returns the player's combined progress multiplier for an attribute. Every multiplier adds
  -- its value minus one on top of 1, and the result is never lower than 1.
  -- @param attribute_id [String]
  -- @return [Number]
  function player_meta:get_attribute_multiplier(attribute_id)
    local attribute = self:get_attribute_data(attribute_id)
    local multiplier = 0

    if !attribute then return 1 end

    local multipliers = attribute.multipliers

    if multipliers then
      for k, v in pairs(multipliers) do
        multiplier = multiplier + (tonumber(v.value) or 1) - 1
      end
    end

    return math_max(multiplier, 0) + 1
  end

  if SERVER then
    --- Sets the player's level in an attribute, rounded and clamped to the attribute's min
    -- and max, and networks it. The progress stays as it is. Server only.
    -- @param attribute_id [String]
    -- @param level [Number]
    -- @see [Attributes.update]
    function player_meta:set_attribute(attribute_id, level)
      level = tonumber(level)

      if !level then return end

      Attributes.update(self, attribute_id, level)
    end

    --- Raises the player's level in an attribute. Boosts are not counted. Server only.
    -- @param attribute_id [String]
    -- @param amount=1 [Number levels to add]
    function player_meta:increase_attribute(attribute_id, amount)
      amount = amount or 1

      self:set_attribute(attribute_id, self:get_attribute(attribute_id, true) + amount)
    end

    --- Lowers the player's level in an attribute. Boosts are not counted. Server only.
    -- @param attribute_id [String]
    -- @param amount=1 [Number levels to remove]
    function player_meta:decrease_attribute(attribute_id, amount)
      amount = amount or 1

      self:set_attribute(attribute_id, self:get_attribute(attribute_id, true) - amount)
    end

    --- Adds progress to an attribute, raising or lowering its level whenever a level threshold is
    -- crossed. Does nothing for attributes whose has_progress is false. Unless told not to,
    -- the amount is scaled by the player's multiplier, when the attribute is multipliable,
    -- and by the `attribute_progress_scale` config; the AdjustAttributeProgress hook can then
    -- change it. Server only.
    -- ```
    -- -- Scaled by the player's multiplier when the attribute is multipliable.
    -- target:progress_attribute('lockpicking', 15)
    -- -- Always exactly 15, unless a hook changes it.
    -- target:progress_attribute('lockpicking', 15, true)
    -- ```
    -- @param attribute_id [String]
    -- @param amount [Number progress to add, negative to remove]
    -- @param no_multiplier=false [Boolean do not scale the amount]
    function player_meta:progress_attribute(attribute_id, amount, no_multiplier)
      local attribute_table = stored[attribute_id]
      local attribute = attribute_table and self:get_attribute_data(attribute_id)

      amount = tonumber(amount)

      if !attribute or !amount or attribute_table.has_progress == false then return end

      local base_amount = amount

      if !no_multiplier then
        local scale = tonumber(Config.get('attribute_progress_scale')) or 1

        if attribute_table.multipliable then
          local modifier = self:get_attribute_multiplier(attribute_id)

          if amount < 0 and modifier != 0 then
            modifier = 1 / modifier
          end

          amount = math_round(amount * modifier * scale)
        elseif scale != 1 then
          amount = math_round(amount * scale)
        end
      end

      local progress_data = {
        amount = amount,
        base_amount = base_amount,
        attribute = attribute_table,
        no_multiplier = no_multiplier == true
      }

      --- Lets plugins change the progress a player is about to gain or lose in an attribute.
      -- Called on the server by `Player:progress_attribute`, after the amount has been scaled
      -- by the player's multiplier and the `attribute_progress_scale` config and before it
      -- is applied. Every handler may change the table, so a handler should return nothing
      -- to let the others run.
      -- ```
      -- function PLUGIN:AdjustAttributeProgress(actor, attribute_id, progress_data)
      --   if attribute_id == 'strength' and actor:is_tired() then
      --     progress_data.amount = progress_data.amount * 0.5
      --   end
      -- end
      -- ```
      -- @param actor [Player The player whose attribute is progressing]
      -- @param attribute_id [String Attribute ID]
      -- @param progress_data [Map The progress, modified in place: amount (Number progress
      --   that is going to be added, negative to remove; a changed amount is rounded, and 0
      --   or anything that is not a number cancels the progress), base_amount (Number the
      --   amount before scaling), attribute (AttributeBase the attribute definition) and
      --   no_multiplier (Boolean whether the amount was left unscaled)]
      hook.Run('AdjustAttributeProgress', self, attribute_id, progress_data)

      local adjusted = tonumber(progress_data.amount)

      if !adjusted or adjusted != adjusted then return end

      if adjusted != amount then
        amount = math_round(adjusted)
      end

      if amount == 0 then return end

      local level = attribute.level or attribute_table.default
      local progress = (attribute.progress or 0) + amount
      local total_progress = attribute_table:get_total_progress(level)

      while progress >= total_progress and level < attribute_table.max do
        progress = progress - total_progress
        level = level + 1
        total_progress = attribute_table:get_total_progress(level)
      end

      while progress < 0 and level > attribute_table.min do
        level = level - 1
        total_progress = attribute_table:get_total_progress(level)
        progress = progress + total_progress
      end

      if level == attribute_table.max or progress < 0 then
        progress = 0
      end

      Attributes.update(self, attribute_id, level, progress)
    end

    --- Removes progress from an attribute, lowering its level when needed. Server only.
    -- @param attribute_id [String]
    -- @param amount [Number progress to remove]
    -- @see [Player#progress_attribute]
    function player_meta:regress_attribute(attribute_id, amount)
      self:progress_attribute(attribute_id, -amount)
    end

    --- Adds a boost to the player's level in an attribute. The boost is stored on the
    -- character, networked, and removed when it expires. A boost that is given an identifier
    -- replaces the boosts of the attribute that carry the same identifier, and can be
    -- removed with `Player:remove_attribute_boost`. Server only.
    -- ```
    -- -- Two extra levels of strength for five minutes.
    -- target:boost_attribute('strength', 2, 300)
    -- -- One level less for as long as the character is drunk.
    -- target:boost_attribute('strength', -1, nil, 'drunk')
    -- ```
    -- @param attribute_id [String attribute to boost; ignored when it is not boostable]
    -- @param value [Number levels to add, negative to take levels away]
    -- @param duration=nil [Number seconds until the boost expires; it never expires if this
    --   is nil or not above 0]
    -- @param identifier=nil [Any name of the boost, kept as a string]
    -- @return [AttributeBoost the record of the boost, or nil if it was not added]
    function player_meta:boost_attribute(attribute_id, value, duration, identifier)
      local attribute_table = stored[attribute_id]

      if !attribute_table or attribute_table.boostable == false then return end

      return Attributes.add_modifier(
        self,
        attribute_id,
        'attribute_boosts',
        AttributeBoost,
        value,
        duration,
        identifier
      )
    end

    --- Removes boosts from the player's character: all of them, those of one attribute,
    -- those with one identifier, or the boost of one attribute with one identifier.
    -- Server only.
    -- ```
    -- target:remove_attribute_boosts()                    -- every boost
    -- target:remove_attribute_boosts('strength')          -- every boost to strength
    -- target:remove_attribute_boosts(nil, 'drunk')        -- 'drunk' boosts to any attribute
    -- target:remove_attribute_boosts('strength', 'drunk') -- the 'drunk' boost to strength
    -- ```
    -- @param attribute_id=nil [String only remove the boosts to this attribute]
    -- @param identifier=nil [Any only remove the boosts with this identifier]
    -- @return [Number amount of boosts removed]
    function player_meta:remove_attribute_boosts(attribute_id, identifier)
      return Attributes.clear_modifiers(self, 'attribute_boosts', attribute_id, identifier)
    end

    --- Removes the boost with the given identifier from one attribute of the player's
    -- character. Server only.
    -- @param attribute_id [String]
    -- @param identifier [Any identifier the boost was given]
    -- @return [Boolean true if a boost was removed]
    -- @see [Player#remove_attribute_boosts]
    function player_meta:remove_attribute_boost(attribute_id, identifier)
      if attribute_id == nil or identifier == nil then return false end

      return self:remove_attribute_boosts(attribute_id, identifier) > 0
    end

    --- Adds a progress multiplier to an attribute of the player. The multiplier is stored on
    -- the character, networked, and removed when it expires. A multiplier that is given an
    -- identifier replaces the multipliers of the attribute that carry the same identifier.
    -- Server only.
    -- ```
    -- -- Double strength progress for an hour.
    -- target:multiply_attribute('strength', 2, 3600)
    -- ```
    -- @param attribute_id [String attribute to affect; ignored when multipliable is false]
    -- @param value [Number multiplier, 2 doubles the progress gained]
    -- @param duration=nil [Number seconds until the multiplier expires; it never expires if
    --   this is nil or not above 0]
    -- @param identifier=nil [Any name of the multiplier, kept as a string]
    -- @return [AttributeMultiplier the record of the multiplier, or nil if it was not added]
    -- @see [Player#get_attribute_multiplier]
    function player_meta:multiply_attribute(attribute_id, value, duration, identifier)
      local attribute_table = stored[attribute_id]

      if !attribute_table or attribute_table.multipliable == false then return end

      return Attributes.add_modifier(
        self,
        attribute_id,
        'attribute_multipliers',
        AttributeMultiplier,
        value,
        duration,
        identifier
      )
    end

    --- Removes progress multipliers from the player's character: all of them, those of one
    -- attribute, those with one identifier, or the multiplier of one attribute with one
    -- identifier. Server only.
    -- @param attribute_id=nil [String only remove the multipliers of this attribute]
    -- @param identifier=nil [Any only remove the multipliers with this identifier]
    -- @return [Number amount of multipliers removed]
    function player_meta:remove_attribute_multipliers(attribute_id, identifier)
      return Attributes.clear_modifiers(self, 'attribute_multipliers', attribute_id, identifier)
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
