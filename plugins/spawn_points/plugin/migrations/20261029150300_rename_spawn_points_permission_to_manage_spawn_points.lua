--- Migration that gives the users and characters that hold the `spawn_points` permission the
-- `manage_spawn_points` permission instead, in the permission tables of Bolt. Rolling back gives them
-- `spawn_points` again.

local RenameSpawnPointsPermissionToManageSpawnPoints = ActiveRecord.Migration.new()

local tables = { 'permissions', 'temp_permissions', 'character_permissions', 'character_temp_permissions' }

--- Changes the stored permission ID from spawn_points to manage_spawn_points.
function RenameSpawnPointsPermissionToManageSpawnPoints:up()
  for _, table_name in ipairs(tables) do
    execute('UPDATE '..table_name.." SET permission_id = 'manage_spawn_points' WHERE permission_id = 'spawn_points';")
  end
end

--- Changes the stored permission ID from manage_spawn_points back to spawn_points.
function RenameSpawnPointsPermissionToManageSpawnPoints:down()
  for _, table_name in ipairs(tables) do
    execute('UPDATE '..table_name.." SET permission_id = 'spawn_points' WHERE permission_id = 'manage_spawn_points';")
  end
end

return RenameSpawnPointsPermissionToManageSpawnPoints
