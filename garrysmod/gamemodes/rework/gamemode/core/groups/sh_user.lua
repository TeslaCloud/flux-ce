--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local USER = Group("user");
	USER:SetName("User");
	USER:SetDescription("A regular user.");
	USER:SetColor(Color(255, 255, 255));
	USER:SetImmunity(0);
	USER:SetPermissions({
		test = PERM_ALLOW
	})

	-- Called when player's primary group is being set to this group.
	function USER:OnGroupSet(player, oldGroup) 

	end;

	-- Called when player's primary group is taken or modified.
	function USER:OnGroupTake(player, newGroup) 

	end;

	-- Called when player is being added to this group as secondary group.
	function USER:OnGroupAdd(player, secondaryGroups) 

	end;

	-- Called when player is being removed from this group as secondary group.
	function USER:OnGroupRemove(player) 

	end;

USER:Register();