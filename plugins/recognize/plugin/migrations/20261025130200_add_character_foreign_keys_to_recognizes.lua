--- Migration that adds foreign keys with ON DELETE CASCADE from the `character_id` and
-- `target_id` columns of the `recognizes` table to `characters`, along with an index on each
-- column, so that the database deletes the recognitions a character has and those of it
-- together with the character, also when the character is deleted along with its user. The
-- rows that name a character that does not exist are deleted first.

local AddCharacterForeignKeysToRecognizes = ActiveRecord.Migration.new()

local columns = { 'character_id', 'target_id' }

--- Deletes the recognitions of characters that do not exist, and adds the indexes and the
-- foreign keys.
function AddCharacterForeignKeysToRecognizes:up()
  for _, column in ipairs(columns) do
    clean_orphans('recognizes', 'characters', { column = column, on_delete = 'cascade' })
    add_index('recognizes', column)
    add_foreign_key('recognizes', 'characters', { column = column, on_delete = 'cascade' })
  end
end

--- Removes the foreign keys and the indexes.
function AddCharacterForeignKeysToRecognizes:down()
  for _, column in ipairs(columns) do
    remove_foreign_key('recognizes', { column = column })
    remove_index('recognizes', column)
  end
end

return AddCharacterForeignKeysToRecognizes
