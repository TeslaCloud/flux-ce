--- The database record of a player, stored in the `users` table: their SteamID, their
-- name and any columns that plugins add.
-- `Player:restore_player` loads or creates the record when a player joins and stores it in
-- the `record` field of the player; the record points back to the player through its
-- `player` field, which is passed on to child records. `Player:save_player` saves it.

class 'User' extends 'ActiveRecord::Base'

--- Called by ActiveRecord when a child record is attached to this user. Copies the user's
-- player reference to the child.
-- @param child_obj [ActiveRecord::Base the child record]
-- @param child_class [Map class of the child record]
function User:as_parent(child_obj, child_class)
  child_obj.player = self.player
end
