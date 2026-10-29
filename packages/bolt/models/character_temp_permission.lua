--- Database record of a temporary permission of a character: the permission ID, its `PERM_`
-- value (the `object` column) and the time at which it expires. Belongs to a `Character`; the
-- relation is set up by Bolt's `OnPluginsLoaded` handler once the Characters plugin has
-- defined the model. Records are created and changed with `Bolt:set_character_temp_permission`.
-- @module [CharacterTempPermission]

class 'CharacterTempPermission' extends 'ActiveRecord::Base'

--- Called by ActiveRecord once the record has been inserted. The character permission
-- functions mark a record whose insert is still running when it is changed or deleted: a
-- changed record is saved again with its current values, and a deleted one is deleted.
function CharacterTempPermission:after_create()
  if self.destroy_on_create then
    self:destroy()
  elseif self.save_on_create then
    self.save_on_create = nil

    self:save()
  end
end
