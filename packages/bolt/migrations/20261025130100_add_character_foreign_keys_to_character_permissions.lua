--- Migration that adds foreign keys with ON DELETE CASCADE from the `character_id` column of
-- the `character_permissions` and `character_temp_permissions` tables to `characters`, so
-- that the database deletes the permissions of a character together with it, also when the
-- character is deleted along with its user rather than by Bolt. The rows that belong to
-- characters that do not exist are deleted first.
--
-- Bolt also runs without the Characters plugin, so the foreign keys are only added if the
-- `characters` table exists when the migration runs. Without them, Bolt still deletes the
-- permissions of a character that a player deletes.

local AddCharacterForeignKeysToCharacterPermissions = ActiveRecord.Migration.new()

local tables = { 'character_permissions', 'character_temp_permissions' }

--- Deletes the permissions of characters that do not exist and adds the foreign keys, if
-- the characters table exists.
function AddCharacterForeignKeysToCharacterPermissions:up()
  if !table_exists('characters') then return end

  for _, table_name in ipairs(tables) do
    clean_orphans(table_name, 'characters', { column = 'character_id', on_delete = 'cascade' })
    add_foreign_key(table_name, 'characters', { column = 'character_id', on_delete = 'cascade' })
  end
end

--- Removes the foreign keys, if they were added.
function AddCharacterForeignKeysToCharacterPermissions:down()
  for _, table_name in ipairs(tables) do
    if foreign_key_exists(table_name, 'characters', { column = 'character_id' }) then
      remove_foreign_key(table_name, 'characters')
    end
  end
end

return AddCharacterForeignKeysToCharacterPermissions
