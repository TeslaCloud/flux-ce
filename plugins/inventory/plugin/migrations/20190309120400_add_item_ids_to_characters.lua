--- Migration that adds the `item_ids` column to the `characters` table.
-- The column holds the instance ids of the items of a character as a comma-separated string.

local AddItemIdsToCharacters = ActiveRecord.Migration.new()

--- Adds the item_ids column to characters.
function AddItemIdsToCharacters:change()
  add_column('characters', 'item_ids', 'text', { null = true })
end

return AddItemIdsToCharacters
