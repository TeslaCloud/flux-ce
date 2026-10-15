--- Registry of the attribute definitions, together with the player methods that read and
-- change the attributes of a player's character.
-- Definitions are `AttributeBase` objects registered with `Attributes.register`, usually
-- by `Attributes.include_attributes` loading the files of a plugin's `attributes` folder.
-- This file adds `attributes` to the extra folders of every plugin and handles that folder
-- through the PluginIncludeFolder hook. It is part of the lib folder of the Stats plugin,
-- which Flux includes before the other folders of the plugin and before its sh_plugin.lua, so
-- the attributes folder of the Stats plugin is loaded this way too, as are those of the
-- plugins and the schema that load after it. For the same reason it includes the sh_enums.lua
-- of the plugin, which defines `CHAR_ERR_ATTRIBUTE_SUM`.
--
-- What a character has of an attribute is kept in an `Attribute` record: a level and any
-- number of boosts. A level changes only when it is set, by staff or by the code of a
-- plugin, such as the Levels plugin spending a point on it. A boost may carry an identifier,
-- which lets the code that gave it replace or remove it later, and may have no expiry, in
-- which case it stays until it is removed. The server networks the attributes of a player to
-- that player alone, in the private 'attributes' networked variable, which the getters read
-- on the client.

mod 'Attributes'

local istable = istable
local tonumber = tonumber
local tostring = tostring
local math_clamp = math.clamp
local math_round = math.round
local os_time = os.time

local stored = Attributes.stored or {}
Attributes.stored = stored

require_relative(PLUGIN:get_folder()..'/sh_enums')

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

--- Stores an attribute definition and runs the AttributeRegistered hook. Missing fields get
-- defaults: min 0, max 10 and default equal to min.
-- ```
-- local attribute = AttributeBase.new('sanity')
-- attribute.name = 'attribute.sanity.name'
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
  data.hidden = data.hidden
  data.boostable = data.boostable
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
    for _, boost_data in pairs(boosts) do
      boost = boost + (tonumber(boost_data.value) or 0)
    end
  end

  if attribute_table.boost_limited then
    local level = attribute.level or attribute_table.default

    boost = math_clamp(level + boost, attribute_table.min, attribute_table.max) - level
  end

  return boost
end

--- Checks whether an attribute is shown to a player on the character sheet. An attribute
-- with its hidden field set is never shown; any other can be hidden with the
-- IsAttributeVisible hook.
-- @param attribute [AttributeBase attribute definition]
-- @param target [Player player whose attributes are being shown]
-- @return [Boolean]
function Attributes.is_visible(attribute, target)
  if !attribute or attribute.hidden then return false end

  --- Lets plugins hide an attribute from a player, for example one that the faction of the
  -- player has no use for. Called on the client for every registered attribute that does
  -- not have its hidden field set, when the tab menu is opened and twice a second while the
  -- character sheet is open, so that the sheet follows a changed answer.
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

  --- Returns the time at which a boost record expires.
  -- @param modifier [AttributeBoost]
  -- @return [Number/Boolean unix timestamp, 0 if the stored time cannot be read, or false
  --   if the record has no expiry]
  local function get_expiry(modifier)
    local expires_at = modifier.expires_at

    if expires_at == nil or expires_at == '' or expires_at == 'NULL' then
      return false
    end

    return time_from_timestamp(expires_at) or 0
  end

  --- Deletes a boost record from the database. A record that has never been saved has
  -- nothing to delete, and one that is being inserted is deleted once the database has given
  -- it an ID.
  -- @param modifier [AttributeBoost]
  local function destroy_record(modifier)
    if modifier.id then
      modifier:destroy()
    elseif modifier.fetched then
      modifier.after_create = function(obj)
        obj:destroy()
      end
    end
  end

  --- Removes boost records from a list and deletes them from the database.
  -- @param modifiers [List<AttributeBoost> records of one attribute]
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

  --- Converts the boost records of an attribute to the tables that are networked, leaving
  -- out the ones that have expired.
  -- @param modifiers [List<AttributeBoost> records of one attribute]
  -- @param unix_time [Number current os.time()]
  -- @param cur_time [Number current CurTime()]
  -- @return [List<Map> networkable tables, Number earliest unix time at which a record of
  --   the list expires or has expired; nil if none has an expiry]
  local function modifiers_to_networkable(modifiers, unix_time, cur_time)
    local entries = {}
    local earliest

    for _, modifier in ipairs(modifiers) do
      local expiry = get_expiry(modifier)

      if expiry and (!earliest or expiry < earliest) then
        earliest = expiry
      end

      if !expiry or expiry > unix_time then
        entries[#entries + 1] = {
          value = tonumber(modifier.value) or 0,
          id = modifier.identifier != nil and tostring(modifier.identifier) or nil,
          expires_at = expiry and modifier.expires_at or nil,
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
  -- @return [Map level and boosts, Number earliest unix time at which a boost of the record
  --   expires or has expired; nil if none has an expiry]
  local function record_to_networkable(record, attribute_table, unix_time, cur_time)
    local boosts, earliest = modifiers_to_networkable(record.attribute_boosts or {}, unix_time, cur_time)

    return {
      level = tonumber(record.level) or attribute_table.default,
      boosts = boosts
    }, earliest
  end

  --- Finds the record that a character keeps for an attribute.
  -- @param character [Character character record; anything else finds nothing]
  -- @param attribute_id [String]
  -- @return [Attribute the record, or nil if the character has none]
  function Attributes.get_record(character, attribute_id)
    if !istable(character) or !istable(character.attributes) then return end

    for _, record in ipairs(character.attributes) do
      if record.attribute_id == attribute_id then
        return record
      end
    end
  end

  --- Returns the level and the boosts of one attribute of a player's character, in the form
  -- that is networked.
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
  -- max, or at the attribute's default level. The records are saved with the character.
  -- @param character [Character]
  -- @param levels=nil [Map starting levels keyed by attribute ID]
  -- @return [Number amount of records added]
  function Attributes.create_records(character, levels)
    if !istable(character) or !istable(character.attributes) then return 0 end

    levels = istable(levels) and levels or {}

    local added = 0

    for attribute_id, attribute_table in pairs(stored) do
      if !Attributes.get_record(character, attribute_id) then
        local level = tonumber(levels[attribute_id])

        if !level or level != level then
          level = attribute_table.default
        end

        local attribute = Attribute.new()
          attribute.attribute_id = attribute_id
          attribute.level = math_clamp(math.floor(level), attribute_table.min, attribute_table.max)
        table.insert(character.attributes, attribute)

        added = added + 1
      end
    end

    return added
  end

  --- Builds the table that is networked for a player: the level and the boosts of every
  -- registered attribute their character has a record for.
  -- @param target [Player]
  -- @return [Map attribute data keyed by attribute ID, Number earliest unix time at which a
  --   boost of the character expires or has expired; nil if none has an expiry]
  function Attributes.to_networkable(target)
    local attributes = {}
    local unix_time, cur_time = os_time(), CurTime()
    local earliest

    for _, record in ipairs(get_records(target)) do
      local attribute_table = stored[record.attribute_id]

      if attribute_table then
        local entry, expiry = record_to_networkable(record, attribute_table, unix_time, cur_time)

        if expiry and (!earliest or expiry < earliest) then
          earliest = expiry
        end

        attributes[record.attribute_id] = entry
      end
    end

    return attributes, earliest
  end

  --- Networks the attributes of a player's character to that player again and notes when
  -- the next of its boosts expires. Called after every change the plugin
  -- makes; call it yourself after changing the records directly.
  -- @param target [Player]
  function Attributes.sync(target)
    if !IsValid(target) then return end

    local attributes, earliest = Attributes.to_networkable(target)

    target.attribute_expiry = earliest
    target:set_private_nv('attributes', attributes)
  end

  --- Removes the boosts of a player's character that have expired, deleting their records.
  -- Does not network the change, see `Attributes.sync`.
  -- @param target [Player]
  -- @return [Number amount of boosts removed]
  function Attributes.remove_expired(target)
    local unix_time = os_time()
    local removed = 0

    for _, record in ipairs(get_records(target)) do
      removed = removed + remove_modifiers(record.attribute_boosts or {}, nil, unix_time)
    end

    return removed
  end

  --- Sets the level of an attribute of a player's character, networks the attributes and
  -- runs the PlayerAttributeChanged hook. Nothing happens if the level does not change or the
  -- character has no record for the attribute.
  -- @param target [Player]
  -- @param attribute_id [String]
  -- @param level [Number new level, rounded and kept between the attribute's min and max]
  -- @return [Boolean true if the level has changed]
  function Attributes.update(target, attribute_id, level)
    local attribute_table = stored[attribute_id]
    local record = attribute_table and Attributes.get_record(get_character(target), attribute_id)

    if !record then return false end

    local old_level = tonumber(record.level) or attribute_table.default

    level = tonumber(level)

    if !level or level != level then return false end

    level = math_clamp(math_round(level), attribute_table.min, attribute_table.max)

    if level == old_level then return false end

    record.level = level

    Attributes.sync(target)

    --- Called on the server after the level of an attribute of a player's character has
    -- changed and the change has been networked, however it came about: through
    -- `Player:set_attribute` and the methods built on it, the staff commands or the points
    -- the Levels plugin lets players spend. Boosts do not run it.
    -- @param actor [Player The player whose character the attribute belongs to]
    -- @param attribute_id [String Attribute ID]
    -- @param level [Number New level, without boosts]
    -- @param old_level [Number Level before the change]
    hook.Run('PlayerAttributeChanged', target, attribute_id, level, old_level)

    return true
  end

  --- Gives a player's character a boost and networks the attributes. A boost that carries an
  -- identifier replaces those of the same attribute with that identifier. This is what
  -- `Player:boost_attribute` is built on; it does not check whether the attribute is
  -- boostable.
  -- @param target [Player]
  -- @param attribute_id [String]
  -- @param list_key [String field of the Attribute record that holds the records,
  --   'attribute_boosts']
  -- @param model [ActiveRecord::Base class of the records, AttributeBoost]
  -- @param value [Number]
  -- @param duration=nil [Number seconds until it expires; it never expires if this is nil
  --   or not above 0]
  -- @param identifier=nil [Any identifier, converted to a string]
  -- @return [AttributeBoost the new record, or nil if the value is not a number or the
  --   character has no record for the attribute]
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

  --- Removes boosts from a player's character and networks the attributes if any were
  -- removed. This is what `Player:remove_attribute_boosts` is built on.
  -- @param target [Player]
  -- @param list_key [String field of the Attribute record that holds the records,
  --   'attribute_boosts']
  -- @param attribute_id=nil [String only remove from this attribute]
  -- @param identifier=nil [Any only remove the ones with this identifier]
  -- @return [Number amount removed]
  function Attributes.clear_modifiers(target, list_key, attribute_id, identifier)
    local removed = 0

    if identifier != nil then
      identifier = tostring(identifier)
    end

    for _, record in ipairs(get_records(target)) do
      if attribute_id == nil or record.attribute_id == attribute_id then
        removed = removed + remove_modifiers(record[list_key] or {}, identifier)
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

  --- Returns the level and the boosts of every attribute of the player's character. On the
  -- client this is what the server has networked, which it does for the local player alone:
  -- any other player has no attributes there. A boost has a value, the identifier it was
  -- given (`id`), the time it expires at as a date-time string (`expires_at`) and as a
  -- CurTime (`end_time`); the last three are nil when not set.
  -- ```
  -- local attributes = target:get_attributes()
  --
  -- -- attributes.strength = {
  -- --   level = 3,
  -- --   boosts = {
  -- --     { value = 2, expires_at = '2026-01-01T12:00:00Z', end_time = 1520 },
  -- --     { value = -1, id = 'drunk' }
  -- --   }
  -- -- }
  -- ```
  -- @return [Map attribute data keyed by attribute ID; empty if the player has no character
  --   or, on the client, nothing has been networked yet or the player is not the local one]
  function player_meta:get_attributes()
    if SERVER then
      local attributes = Attributes.to_networkable(self)

      return attributes
    end

    return self:get_nv('attributes') or {}
  end

  --- Returns the level and the boosts of one attribute of the player's character, in the
  -- form `Player:get_attributes` describes.
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

  --- Returns the player's level in an attribute. Active boosts are added to the level unless
  -- disabled or the attribute is not boostable. A player whose character has no data for the
  -- attribute, such as a bot, is at the attribute's default level.
  -- @param attribute_id [String]
  -- @param no_boost=false [Boolean leave active boosts out of the level]
  -- @return [Number level; 0 if the attribute is not registered]
  function player_meta:get_attribute(attribute_id, no_boost)
    local attribute_table = stored[attribute_id]

    if !attribute_table then return 0 end

    local attribute = self:get_attribute_data(attribute_id)

    if !attribute then
      return attribute_table.default
    end

    local level = attribute.level or attribute_table.default
    local boost = 0

    if !no_boost and attribute_table.boostable != false then
      boost = Attributes.sum_boosts(attribute_table, attribute)
    end

    return level + boost
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

    for _, boost in pairs(self:get_attribute_boosts(attribute_id)) do
      if boost.id == identifier then
        return true
      end
    end

    return false
  end

  if SERVER then
    --- Sets the player's level in an attribute, rounded and clamped to the attribute's min
    -- and max, and networks it. Server only.
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
  end
end

Pipeline.register('attribute', function(id, file_name, _pipe)
  ATTRIBUTE = AttributeBase.new(id)

  require_relative(file_name)

  if Pipeline.is_aborted() then ATTRIBUTE = nil return end

  ATTRIBUTE:register()
  ATTRIBUTE = nil
end)

--- Hook handlers of the attribute registry, registered as `Attributes` while this file is
-- included, before the Stats plugin itself is registered, so that they already handle the
-- folders of the Stats plugin. The handlers registered under that ID by an earlier
-- inclusion of the file are removed first, so they are never registered twice.
local hooks = {}

--- Includes a plugin's attributes folder when the 'attributes' extra is being loaded.
-- @param extra [String name of the extra being loaded]
-- @param folder [String path of the plugin folder]
-- @return [Boolean true when the extra was handled here, otherwise nil]
function hooks:PluginIncludeFolder(extra, folder)
  if extra == 'attributes' then
    Attributes.include_attributes(folder..'/attributes')

    return true
  end
end

Plugin.remove_hooks('Attributes')
Plugin.add_hooks('Attributes', hooks)
Plugin.add_extra('attributes')
