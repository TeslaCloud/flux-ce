--- Migration that gives the users and characters that hold the `spawnpoints` permission the
-- `spawn_points` permission instead, in the permission tables of Bolt. Rolling back gives them
-- `spawnpoints` again.

local RenameSpawnPointsPermission = ActiveRecord.Migration.new()

local tables = { 'permissions', 'temp_permissions', 'character_permissions', 'character_temp_permissions' }

--- Changes the stored permission ID from spawnpoints to spawn_points.
function RenameSpawnPointsPermission:up()
  for _, table_name in ipairs(tables) do
    execute('UPDATE '..table_name.." SET permission_id = 'spawn_points' WHERE permission_id = 'spawnpoints';")
  end
end

--- Changes the stored permission ID from spawn_points back to spawnpoints.
function RenameSpawnPointsPermission:down()
  for _, table_name in ipairs(tables) do
    execute('UPDATE '..table_name.." SET permission_id = 'spawnpoints' WHERE permission_id = 'spawn_points';")
  end
end

return RenameSpawnPointsPermission
