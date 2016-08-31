--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

if (rw.config) then return; end;

library.New("config", rw);
local stored = {};

if (SERVER) then
	function rw.config:Set(key, value, bIsHidden)
		if (key != nil) then
			stored[key] = stored[key] or {};
			stored[key]._Value = value;
			stored[key].hidden = bIsHidden or false;

			if (!stored[key].hidden) then
				netstream.Start(nil, "config_setvar", key, stored[key]);
			end;
		end;
	end;

	local playerMeta = FindMetaTable("Player");

	function playerMeta:SendConfig()
		for k, v in pairs(stored) do
			if (!v.hidden) then
				netstream.Start(self, "config_setvar", k, stored[key]);
			end;
		end;

		player.rwHasSentConfig = true;
	end;
else
	netstream.Hook("config_setvar", function(key, value)
		if (key == nil) then return; end;
		stored[key] = stored[key] or {};
		stored[key]._Value = value;
	end);
end;

function rw.config:Get(key, default)
	if (stored[key] != nil) then
		if (stored[key]._Value != nil) then
			return stored[key]._Value;
		else
			if (stored[key].DefaultValue != nil) then
				return stored[key]._DefaultValue;
			end;
		end;
	end;

	return default;
end;

function rw.config:Register(key, default, modifyFromMenu)
	stored[key] = {_DefaultValue = default, _ModifyFromMenu = (modifyFromMenu or true)};
end;