--- Server side of the attribute registry: the attribute records of characters, their levels
-- and boosts, the expiry of the boosts and what the server networks of them to their owner.

local istable = istable
local tonumber = tonumber
local tostring = tostring
local math_clamp = math.clamp
local math_round = math.round
local os_time = os.time

local stored = Attributes.stored

--- Returns the active character of a player, if they have one.
-- @param target [Player]
-- @return [Character/Map the character record, or the stand-in table of a bot; nil if the
--   player is not valid or has no active character]
local function get_character(target)
  if !IsValid(target) or !target:is_character_loaded() then return end

  return target:get_character()
end

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

      removed += 1
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

--- Returns the level of one attribute of a player's character and the sum of its boosts
-- that have not expired, read from the record without building the networked form.
-- @param target [Player]
-- @param attribute_id [String]
-- @return [Number level and Number sum of the boosts, cut down for an attribute that has
--   boost_limited set; nil if the attribute is not registered or the player's character has
--   no record for it]
function Attributes.get_level(target, attribute_id)
  local attribute_table = stored[attribute_id]
  local record = attribute_table and Attributes.get_record(get_character(target), attribute_id)

  if !record then return end

  local level = tonumber(record.level) or attribute_table.default
  local boosts = record.attribute_boosts
  local boost = 0

  if boosts and boosts[1] then
    local unix_time = os_time()

    for _, modifier in ipairs(boosts) do
      local expiry = get_expiry(modifier)

      if !expiry or expiry > unix_time then
        boost += tonumber(modifier.value) or 0
      end
    end
  end

  if attribute_table.boost_limited then
    boost = math_clamp(level + boost, attribute_table.min, attribute_table.max) - level
  end

  return level, boost
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

      added += 1
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
    removed += remove_modifiers(record.attribute_boosts or {}, nil, unix_time)
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
      removed += remove_modifiers(record[list_key] or {}, identifier)
    end
  end

  if removed > 0 then
    Attributes.sync(target)
  end

  return removed
end
