--- Database record of a temporary permission of a character: the permission ID, its `PERM_`
-- value (the `object` column) and the time at which it expires. Belongs to a `Character`; the
-- relation is set up by Bolt's `PluginsLoaded` handler once the Characters plugin has
-- defined the model. Records are created and changed with `Bolt:set_character_temp_permission`.
-- @module [CharacterTempPermission]

class 'CharacterTempPermission' extends 'ActiveRecord::Base'

--- Called by ActiveRecord once the record has been inserted, see
-- `Bolt:permission_record_created`.
function CharacterTempPermission:after_create()
  Bolt:permission_record_created(self)
end
