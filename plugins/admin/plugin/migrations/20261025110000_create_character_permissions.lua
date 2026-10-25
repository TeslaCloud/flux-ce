--- Migration that creates the tables of the character permissions of the admin plugin,
-- `character_permissions` and `character_temp_permissions`. They hold the same columns as
-- `permissions` and `temp_permissions`, but belong to a character instead of a user. The
-- `character_id` column is indexed; its foreign key to `characters` is added by a later
-- migration, which only adds it if the `characters` table exists, since the admin plugin also
-- runs without the Characters plugin.

local CreateCharacterPermissions = ActiveRecord.Migration.new()

--- Creates the character_permissions and character_temp_permissions tables.
function CreateCharacterPermissions:change()
  create_table('character_permissions', function(t)
    t:string 'permission_id'
    t:integer 'object'
    t:references 'character'
    t:timestamps()
  end)

  create_table('character_temp_permissions', function(t)
    t:string 'permission_id'
    t:integer 'object'
    t:references 'character'
    t:timestamp 'expires'
    t:timestamps()
  end)
end

return CreateCharacterPermissions
