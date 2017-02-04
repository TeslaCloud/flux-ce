--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

GROUP:SetName("User")
GROUP:SetDescription("#PlayerGroup_User")
GROUP:SetColor(Color(255, 255, 255))
GROUP:SetIcon("icon16/user.png")
GROUP:SetImmunity(0)
GROUP:SetPermissions({
	test = PERM_ALLOW
})

-- Called when player's primary group is being set to this group.
function GROUP:OnGroupSet(player, oldGroup) end

-- Called when player's primary group is taken or modified.
function GROUP:OnGroupTake(player, newGroup) end

-- Called when player is being added to this group as secondary group.
function GROUP:OnGroupAdd(player, secondaryGroups) end

-- Called when player is being removed from this group as secondary group.
function GROUP:OnGroupRemove(player) end