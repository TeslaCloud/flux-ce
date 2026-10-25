--- Migration that creates the tables of the character permissions of the admin plugin,
-- `character_permissions` and `character_temp_permissions`. They hold the same columns as
-- `permissions` and `temp_permissions`, but belong to a character instead of a user. The
-- `character_id` column is indexed but has no foreign key, since the admin plugin also runs
-- without the Characters plugin; the plugin deletes the rows of a character when a player
-- deletes it.

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
