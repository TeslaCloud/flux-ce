--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

PLUGIN:SetName("Third Person");
PLUGIN:SetAuthor("NightAngel");
PLUGIN:SetDescription("Provides Third Person View setting for clients.");
PLUGIN.ShouldRefresh = false;

if (SERVER) then
	concommand.Add("rwThirdPerson", function(player)
		local oldValue = player:GetNetVar("rwThirdPerson");

		if (oldValue == nil) then
			oldValue = false;
		end;

		player:SetNetVar("rwThirdPerson", !oldValue);
	end);
else
	local startTime = nil;
	local offset = Vector(0, 0, 0);
	local duration = 0.15;
	local flippedStart = false;

	-- This is very basic and WIP, but it works.
	function PLUGIN:CalcView(ply, pos, angles, fov)
		local view = {};
		local curTime = CurTime();

		view.origin = pos;
		view.angles = angles;
		view.fov = fov;

		if (ply:GetNetVar("rwThirdPerson")) then
			if (!startTime or flippedStart) then
				startTime = curTime;	
				flippedStart = false;
			end;			

			local forward = angles:Forward() * 75;
			local fraction = (curTime - startTime) / duration;

			if (fraction <= 1) then
				offset.x = Lerp(fraction, 0, forward.x);
				offset.y = Lerp(fraction, 0, forward.y);
				offset.z = Lerp(fraction, 0, forward.z);
			else
				offset = forward;
			end;

			view.origin = pos - offset;
			view.drawviewer = true;
		else
			if (!flippedStart) then
				startTime = curTime;
				flippedStart = true;
			end;

			local forward = angles:Forward() * 75;
			local fraction = (curTime - startTime) / duration;

			if (fraction <= 1) then
				offset.x = Lerp(fraction, forward.x, 0);
				offset.y = Lerp(fraction, forward.y, 0);
				offset.z = Lerp(fraction, forward.z, 0);
				view.drawviewer = true;
			else
				offset = Vector(0, 0, 0);
			end;

			view.origin = pos - offset;
		end;

		return view;
	end;

	rw.binds:AddBind("ToggleThirdPerson", "rwThirdPerson", KEY_X);
end;