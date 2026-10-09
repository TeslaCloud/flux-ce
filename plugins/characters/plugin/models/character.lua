--- A character of a player, stored in the `characters` table.
-- It belongs to a `User` and holds the name, gender, physical description, model, skin,
-- health, armor, reserve ammo and ban state of the character; other plugins add their own
-- columns and relations, as Factions does with the faction and rank. A record is only valid
-- with a name and a physical description; how long they may be is set by the
-- `character_min_name_len`, `character_max_name_len`, `character_min_desc_len` and
-- `character_max_desc_len` configs and checked when a character is created or its description
-- is changed by its player. Characters are created and changed through the `Characters`
-- functions and the `Player` extensions rather than directly.
--
-- Two columns hold serialized tables. `data` is the generic data of the character: any plugin
-- can keep values in it under string keys without adding a column, with `Character:get_data`
-- and `Character:set_data`. The decoded table lives in the `custom_data` field of the record
-- and is written back to the column whenever the record is saved. `ammo` holds the reserve
-- ammo as amounts by ammo type name, read and written with `Character:get_ammo` and
-- `Character:set_ammo`.

class 'Character' extends 'ActiveRecord::Base'

Character:belongs_to 'User'

Character:validates('user_id', { presence = true })
Character:validates('steam_id', { presence = true })
Character:validates('name', { presence = true })
Character:validates('gender', { presence = true })
Character:validates('phys_desc', { presence = true })
Character:validates('model', { presence = true })

--- Turns a serialized column value back into a table.
-- @param serialized [String value of the column; anything else counts as empty]
-- @return [Map the decoded table, empty when there is nothing to decode]
local function decode(serialized)
  if isstring(serialized) and serialized != '' then
    local decoded = table.deserialize(serialized)

    if istable(decoded) then
      return decoded
    end
  end

  return {}
end

--- Called by ActiveRecord when the character has been loaded from the database. Decodes the
-- `data` column into the custom_data field.
function Character:restored()
  self.custom_data = decode(self.data)
end

--- Called by ActiveRecord before the character is saved. Serializes the custom_data field
-- into the `data` column; an empty table is stored as NULL. The column is left as it is when
-- the table cannot be serialized.
-- @param fetched [Boolean true when the record already exists in the database]
function Character:before_save(fetched)
  if !istable(self.custom_data) then return end

  if next(self.custom_data) == nil then
    self.data = nil

    return
  end

  local serialized = table.serialize(self.custom_data)

  if serialized != '' then
    self.data = serialized
  end
end

--- Returns a value from the generic data of the character.
-- @param key [String]
-- @param default=nil [Any value to return when nothing is stored under the key]
-- @return [Any]
-- @see [Characters.get_custom_data]
function Character:get_data(key, default)
  return Characters.get_custom_data(self, key, default)
end

--- Sets a value in the generic data of the character. It is written to the database the
-- next time the character is saved, and sent to the owner right away if the key is
-- registered with `Characters.network_data`. Server only.
-- @param key [String nothing happens when it is not a string]
-- @param value [Any anything serializable, so no functions; nil removes the key]
-- @see [Characters.set_custom_data]
function Character:set_data(key, value)
  Characters.set_custom_data(self, key, value)
end

--- Checks whether the character is banned.
-- @return [Boolean]
function Character:is_banned()
  return tobool(self.banned)
end

--- Returns the reserve ammo saved with the character.
-- @return [Map amounts of ammo by ammo type name, empty when none is saved]
function Character:get_ammo()
  return decode(self.ammo)
end

--- Sets the reserve ammo saved with the character. It is written to the database the next
-- time the character is saved.
-- @param ammo [Map amounts of ammo by ammo type name; nil or an empty table clears it]
function Character:set_ammo(ammo)
  if !istable(ammo) or next(ammo) == nil then
    self.ammo = nil

    return
  end

  local serialized = table.serialize(ammo)

  if serialized != '' then
    self.ammo = serialized
  end
end
