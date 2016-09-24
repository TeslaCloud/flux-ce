if (SERVER) then
	concommand.Add("rwThirdPerson", function(player)
		local oldValue = player:GetNetVar("rwThirdPerson");

		if (oldValue == nil) then
			oldValue = false;
		end;

		player:SetNetVar("rwThirdPerson", !oldValue);
	end);
else
	-- This is very basic and WIP, but it works.
	function PLUGIN:CalcView(ply, pos, angles, fov)
		if (ply:GetNetVar("rwThirdPerson")) then
			local view = {};

			view.origin = pos - (angles:Forward() * 75);
			view.angles = angles;
			view.fov = fov;
			view.drawviewer = true;

			return view;
		end;
	end;

	rw.binds.AddBind("ToggleThirdPerson", "rwThirdPerson", KEY_X);
end;