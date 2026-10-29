--- Migration that gives the `gamemaster` role to every user whose stored role is
-- `moderator`, which is not a registered role. Rolling back gives them `moderator` again.

local RenameModeratorRoleToGamemaster = ActiveRecord.Migration.new()

--- Changes the stored role of the users that have the moderator role to gamemaster.
function RenameModeratorRoleToGamemaster:up()
  execute("UPDATE users SET role = 'gamemaster' WHERE role = 'moderator';")
end

--- Changes the stored role of the users that have the gamemaster role back to moderator.
function RenameModeratorRoleToGamemaster:down()
  execute("UPDATE users SET role = 'moderator' WHERE role = 'gamemaster';")
end

return RenameModeratorRoleToGamemaster
