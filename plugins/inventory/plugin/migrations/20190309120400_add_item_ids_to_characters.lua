local AddItemIdsToCharacters = ActiveRecord.Migration.new()

function AddItemIdsToCharacters:change()
  add_column('characters', 'item_ids', 'text', { null = true })
end

return AddItemIdsToCharacters
