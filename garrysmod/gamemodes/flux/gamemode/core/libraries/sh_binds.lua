--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

if (CLIENT) then
	library.New("binds", fl)

	local keyEnums = fl.binds.keyEnums or {}
	fl.binds.keyEnums = keyEnums

	local stored = fl.binds.stored or {}
	fl.binds.stored = stored

	if (#keyEnums == 0) then
		for k, v in pairs(_G) do
			if (string.sub(k, 1, 6) == "MOUSE_") then
				keyEnums[v] = k
			elseif (string.sub(k, 1, 4) == "KEY_") then
				keyEnums[v] = k
			end
		end
	end

	function fl.binds:GetEnums()
		return keyEnums
	end

	function fl.binds:GetAll()
		return stored
	end

	function fl.binds:GetBound()
		local binds = {}

		for k, v in pairs(keyEnums) do
			local bind = input.LookupKeyBinding(k)

			if (!tonumber(bind)) then
				binds[k] = bind
			end
		end

		return binds
	end

	function fl.binds:GetUnbound()
		local binds = {}

		for k, v in pairs(keyEnums) do
			local bind = input.LookupKeyBinding(k)

			if (tonumber(bind)) then
				binds[k] = bind
			end
		end

		return binds
	end

	function fl.binds:GetBind(nKey)
		return stored[nKey]
	end

	function fl.binds:SetBind(command, nKey)
		for k, v in pairs(stored) do
			if (v == command) then
				stored[k] = nil
			end
		end

		stored[nKey] = command
	end

	function fl.binds:AddBind(id, command, default, visibleCallback)
		fl.settings:AddSetting("Binds", id, default, nil, true, "flBindSelect", {command = command}, nil, visibleCallback)
		self:SetBind(command, fl.settings:GetNumber(id))
	end
end

local hooks = {}

if (SERVER) then
	function hooks:PlayerButtonDown(player, nKey)
		netstream.Start(player, "FLBindPressed", nKey)
	end
else
	function hooks:AdjustSettingCallbacks(callbacks)
		callbacks["flBindSelect"] = function(panel, parent, setting)
			local textW = util.GetTextSize("Press a key to bind or mouse away to cancel.", theme.GetFont("Menu_Small"))

			panel:SetSize(textW * 1.2, parent:GetTall() * 0.6)
			panel:SetPos(parent:GetWide() * 0.99 - panel:GetWide(), parent:GetTall() * 0.5 - panel:GetTall() * 0.5)

			panel.setting = setting
		end
	end

	netstream.Hook("FLBindPressed", function(nKey)
		local bind = fl.binds:GetBind(nKey)

		if (bind) then
			RunConsoleCommand(bind)
		end
	end)
end

plugin.AddHooks("FLBinds", hooks)