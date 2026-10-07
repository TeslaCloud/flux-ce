local AddItemIdsToCharacters = ActiveRecord.Migration.new()

--- Adds the item_ids column to characters.
function AddItemIdsToCharacters:change()
  add_column('characters', 'item_ids', 'text', { null = true })
end

return AddItemIdsToCharacters
