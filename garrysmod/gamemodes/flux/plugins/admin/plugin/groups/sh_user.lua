--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

GROUP.Name = "User"
GROUP.Description = "#PlayerGroup_User"
GROUP.Color = Color(255, 255, 255)
GROUP.Icon = "icon16/user.png"
GROUP.Immunity = 0
GROUP.Permissions = {
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
