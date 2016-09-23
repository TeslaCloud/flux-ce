local PLUGIN = PLUGIN;

if (SERVER) then
	local check = {
		[IN_FORWARD] = true,
		[IN_BACK] = true,
		[IN_MOVELEFT] = true,
		[IN_MOVERIGHT] = true
	};

	function PLUGIN:SetupMove(player, moveData, cmdData)
		if (!player:GetNetVar("rwAutoWalk")) then return; end;

		moveData:SetForwardSpeed(moveData:GetMaxSpeed());

		-- If they try to move, break the autowalk.
		for k, v in pairs(check) do
			if (cmdData:KeyDown(k)) then
				player:SetNetVar("rwAutoWalk", false);

				break;
			end;
		end;
	end;

	-- So clients can bind this as they want.
	concommand.Add("toggleautowalk", function(player)
		local oldValue = player:GetNetVar("rwAutoWalk");

		if (!oldValue) then
			oldValue = false;
		end;

		player:SetNetVar("rwAutoWalk", !oldValue);
	end);
else
	-- We do this so there's no need to do an unnecessary check for if client or server in the hook itself.
	function PLUGIN:SetupMove(player, moveData, cmdData)
		if (!player:GetNetVar("rwAutoWalk")) then return; end;

		moveData:SetForwardSpeed(moveData:GetMaxSpeed());
	end;
	
	rw.binds.AddBind("ToggleAutoWalk", "toggleautowalk", KEY_B);
end;