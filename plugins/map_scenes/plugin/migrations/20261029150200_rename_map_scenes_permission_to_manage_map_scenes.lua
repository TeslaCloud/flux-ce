--- Migration that gives the users and characters that hold the `map_scenes` permission the
-- `manage_map_scenes` permission instead, in the permission tables of Bolt. Rolling back gives them
-- `map_scenes` again.

local RenameMapScenesPermissionToManageMapScenes = ActiveRecord.Migration.new()

local tables = { 'permissions', 'temp_permissions', 'character_permissions', 'character_temp_permissions' }

--- Changes the stored permission ID from map_scenes to manage_map_scenes.
function RenameMapScenesPermissionToManageMapScenes:up()
  for _, table_name in ipairs(tables) do
    execute('UPDATE '..table_name.." SET permission_id = 'manage_map_scenes' WHERE permission_id = 'map_scenes';")
  end
end

--- Changes the stored permission ID from manage_map_scenes back to map_scenes.
function RenameMapScenesPermissionToManageMapScenes:down()
  for _, table_name in ipairs(tables) do
    execute('UPDATE '..table_name.." SET permission_id = 'map_scenes' WHERE permission_id = 'manage_map_scenes';")
  end
end

return RenameMapScenesPermissionToManageMapScenes
