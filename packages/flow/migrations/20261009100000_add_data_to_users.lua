--- Migration that adds the `data` column to the `users` table.
-- The column holds the persistent data table of a player (`Player:set_player_data`),
-- serialized with `table.serialize`.

local AddDataToUsers = ActiveRecord.Migration.new()

--- Adds the data column to users.
function AddDataToUsers:change()
  add_column('users', 'data', 'text', { null = true })
end

return AddDataToUsers
