--- Migration that removes the `item_ids` column from the `characters` table.

local RemoveItemIdsFromCharacters = ActiveRecord.Migration.new()

--- Removes the item_ids column from characters.
function RemoveItemIdsFromCharacters:change()
  remove_column('characters', 'item_ids', 'text', { null = true })
end

return RemoveItemIdsFromCharacters
