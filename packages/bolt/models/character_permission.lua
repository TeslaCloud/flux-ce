--- Database record of a permission set on a single character: the permission ID and its
-- `PERM_` value, which is kept in the `object` column. Belongs to a `Character`; the relation
-- is set up by Bolt's `PluginsLoaded` handler once the Characters plugin has defined the
-- model.
-- Records are created and changed with `Bolt:set_character_permission`.
-- @module [CharacterPermission]

class 'CharacterPermission' extends 'ActiveRecord::Base'

--- Called by ActiveRecord once the record has been inserted, see
-- `Bolt:permission_record_created`.
function CharacterPermission:after_create()
  Bolt:permission_record_created(self)
end
