--- Migration that gives the users and characters that hold the `areas` permission the
-- `manage_areas` permission instead, in the permission tables of Bolt. Rolling back gives them
-- `areas` again.

local RenameAreasPermission = ActiveRecord.Migration.new()

local tables = { 'permissions', 'temp_permissions', 'character_permissions', 'character_temp_permissions' }

--- Changes the stored permission ID from areas to manage_areas.
function RenameAreasPermission:up()
  for _, table_name in ipairs(tables) do
    execute('UPDATE '..table_name.." SET permission_id = 'manage_areas' WHERE permission_id = 'areas';")
  end
end

--- Changes the stored permission ID from manage_areas back to areas.
function RenameAreasPermission:down()
  for _, table_name in ipairs(tables) do
    execute('UPDATE '..table_name.." SET permission_id = 'areas' WHERE permission_id = 'manage_areas';")
  end
end

return RenameAreasPermission
