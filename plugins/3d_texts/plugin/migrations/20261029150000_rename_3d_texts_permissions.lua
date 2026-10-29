--- Migration that gives the users and characters that hold the `texts` and `pictures`
-- permissions the `manage_texts` and `manage_pictures` permissions instead, in the permission
-- tables of Bolt. Rolling back gives them `texts` and `pictures` again.

local Rename3dTextsPermissions = ActiveRecord.Migration.new()

local tables = { 'permissions', 'temp_permissions', 'character_permissions', 'character_temp_permissions' }
local renames = { texts = 'manage_texts', pictures = 'manage_pictures' }

--- Changes the stored permission IDs from texts and pictures to manage_texts and
-- manage_pictures.
function Rename3dTextsPermissions:up()
  for _, table_name in ipairs(tables) do
    for old_id, new_id in pairs(renames) do
      execute('UPDATE '..table_name.." SET permission_id = '"..new_id.."' WHERE permission_id = '"..old_id.."';")
    end
  end
end

--- Changes the stored permission IDs from manage_texts and manage_pictures back to texts and
-- pictures.
function Rename3dTextsPermissions:down()
  for _, table_name in ipairs(tables) do
    for old_id, new_id in pairs(renames) do
      execute('UPDATE '..table_name.." SET permission_id = '"..old_id.."' WHERE permission_id = '"..new_id.."';")
    end
  end
end

return Rename3dTextsPermissions
