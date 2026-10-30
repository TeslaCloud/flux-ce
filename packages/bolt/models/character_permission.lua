--- Database record of a permission set on a single character: the permission ID and its
-- `PERM_` value, which is kept in the `object` column. Belongs to a `Character`; the relation
-- is set up by Bolt's `PluginsLoaded` handler once the Characters plugin has defined the
-- model.
-- Records are created and changed with `Bolt:set_character_permission`.
-- @module [CharacterPermission]

class 'CharacterPermission' extends 'ActiveRecord::Base'

--- Called by ActiveRecord once the record has been inserted. The character permission
-- functions mark a record whose insert is still running when it is changed or deleted: a
-- changed record is saved again with its current values, and a deleted one is deleted.
function CharacterPermission:after_create()
  if self.destroy_on_create then
    self:destroy()
  elseif self.save_on_create then
    self.save_on_create = nil

    self:save()
  end
end
