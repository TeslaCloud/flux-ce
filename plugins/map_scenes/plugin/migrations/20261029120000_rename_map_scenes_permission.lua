--- Migration that gives the users and characters that hold the `mapscenes` permission the
-- `map_scenes` permission instead, in the permission tables of Bolt. Rolling back gives them
-- `mapscenes` again.

local RenameMapScenesPermission = ActiveRecord.Migration.new()

local tables = { 'permissions', 'temp_permissions', 'character_permissions', 'character_temp_permissions' }

--- Changes the stored permission ID from mapscenes to map_scenes.
function RenameMapScenesPermission:up()
  for _, table_name in ipairs(tables) do
    execute('UPDATE '..table_name.." SET permission_id = 'map_scenes' WHERE permission_id = 'mapscenes';")
  end
end

--- Changes the stored permission ID from map_scenes back to mapscenes.
function RenameMapScenesPermission:down()
  for _, table_name in ipairs(tables) do
    execute('UPDATE '..table_name.." SET permission_id = 'mapscenes' WHERE permission_id = 'map_scenes';")
  end
end

return RenameMapScenesPermission
