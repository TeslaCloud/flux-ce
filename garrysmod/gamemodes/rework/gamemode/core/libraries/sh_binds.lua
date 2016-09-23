--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

if (CLIENT) then
	library.New("binds", rw);

	local keyEnums = rw.binds.keyEnums or {};
	rw.binds.keyEnums = keyEnums;

	local stored = rw.binds.stored or {};
	rw.binds.stored = stored;

	if (#keyEnums == 0) then
		for k, v in pairs(_G) do
			if (string.sub(k, 1, 4) == "KEY_") then
				keyEnums[v] = k;
			end;
		end;
	end;

	function rw.binds.GetEnums()
		return keyEnums;
	end;

	function rw.binds.GetStored()
		return stored;
	end;

	function rw.binds.GetBound()
		local binds = {};

		for k, v in pairs(keyEnums) do
			local bind = input.LookupKeyBinding(k);

			if (!tonumber(bind)) then
				binds[k] = bind;
			end;
		end;

		return binds;
	end;

	function rw.binds.GetUnbound()
		local binds = {};

		for k, v in pairs(keyEnums) do
			local bind = input.LookupKeyBinding(k);

			if (tonumber(bind)) then
				binds[k] = bind;
			end;
		end;

		return binds;
	end;

	function rw.binds.GetBind(nKey)
		return stored[nKey];
	end;

	function rw.binds.SetBind(command, nKey)
		for k, v in pairs(stored) do
			if (v == command) then
				stored[k] = nil;
			end;
		end;

		stored[nKey] = command;
	end;

	function rw.binds.AddBind(id, command, default, visibleCallback)
		rw.settings.AddSetting("Binds", id, default, nil, true, "rwBindSelect", {command = command}, nil, visibleCallback);
		rw.binds.SetBind(command, rw.settings.GetNumber(id));
	end;
end;

local hooks = {};

if (SERVER) then
	function hooks:PlayerButtonDown(player, nKey)
		netstream.Start(player, "RWBindPressed", nKey);
	end;
else
	function hooks:AdjustSettingCallbacks(callbacks)
		callbacks["rwBindSelect"] = function(panel, parent, setting)
			local textW = util.GetTextSize("menu_light_small", "Press a key to bind or mouse away to cancel.");

			panel:SetSize(textW * 1.2, parent:GetTall() * 0.6);
			panel:SetPos(parent:GetWide() * 0.99 - panel:GetWide(), parent:GetTall() * 0.5 - panel:GetTall() * 0.5);

			panel.setting = setting;
		end;
	end;

	netstream.Hook("RWBindPressed", function(nKey)
		local bind = rw.binds.GetBind(nKey);

		if (bind) then
			RunConsoleCommand(bind);
		end;
	end);
end;

plugin.AddHooks("RWBinds", hooks);