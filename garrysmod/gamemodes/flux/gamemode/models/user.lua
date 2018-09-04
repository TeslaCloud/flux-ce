class 'User' extends 'ActiveRecord::Base'

function User:as_parent(child_obj, child_class)
  child_obj.player = self.player
end
