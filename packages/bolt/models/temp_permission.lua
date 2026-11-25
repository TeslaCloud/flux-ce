--- Database record of a temporary permission of a user: the permission ID, its `PERM_` value
-- (the `object` column) and the time at which it expires. Belongs to a `User`.
-- @module [TempPermission]

class 'TempPermission' extends 'ActiveRecord::Base'

TempPermission:belongs_to 'User'

--- Called by ActiveRecord once the record has been inserted, see
-- `Bolt:permission_record_created`.
function TempPermission:after_create()
  Bolt:permission_record_created(self)
end
