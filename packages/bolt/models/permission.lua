--- Database record of a permission set on a single user: the permission ID and its `PERM_`
-- value, which is kept in the `object` column. Belongs to a `User`.
-- @module [Permission]

class 'Permission' extends 'ActiveRecord::Base'

Permission:belongs_to 'User'
