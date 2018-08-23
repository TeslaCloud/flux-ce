GROUP.name = "User"
GROUP.description = "#PlayerGroup_User"
GROUP.color = Color(255, 255, 255)
GROUP.icon = "icon16/user.png"
GROUP.immunity = 0
GROUP.permissions = {
  test = PERM_ALLOW
}

-- Called when player's primary group is being set to this group.
function GROUP:OnGroupSet(player, oldGroup) end

-- Called when player's primary group is taken or modified.
function GROUP:OnGroupTake(player, newGroup) end

-- Called when player is being added to this group as secondary group.
function GROUP:OnGroupAdd(player, secondaryGroups) end

-- Called when player is being removed from this group as secondary group.
function GROUP:OnGroupRemove(player) end
