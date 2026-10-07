class 'User' extends 'ActiveRecord::Base'

--- Called by ActiveRecord when a child record is attached to this user. Copies the user's
-- player reference to the child.
-- @param child_obj [ActiveRecord::Base the child record]
-- @param child_class [Map class of the child record]
function User:as_parent(child_obj, child_class)
  child_obj.player = self.player
end
