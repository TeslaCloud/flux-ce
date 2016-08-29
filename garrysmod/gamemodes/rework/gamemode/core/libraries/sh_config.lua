--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

if (rw.config) then return; end;

library.New("config", rw);
local stored = {};

if (SERVER) then
	function rw.config:Set(key, value)
		if (key != nil) then
			if (typeof(stored[key]) == "table" and stored[key]._DefaultValue) then
				stored[key]._Value = value;
			else
				stored[key] = value;
			end;

			netstream.Start(nil, "config_setvar", key, stored[key]);
		end;
	end;

	local playerMeta = FindMetaTable("Player");

	function playerMeta:SendConfig()
		for k, v in pairs(stored) do
			netstream.Start(self, "config_setvar", key, stored[key]);
		end;

		player.rwHasSentConfig = true;
	end;
else
	netstream.Hook("config_setvar", function(key, value)
		stored[key] = value;
	end;
end;

function rw.config:Get(key, default)
	if (stored[key] != nil) then
		if (stored[key]._Value != nil) then
			return stored[key]._Value;
		else
			if (stored[key].DefaultValue != nil) then
				return stored[key]._DefaultValue;
			end;

			return stored[key];
		end;
	end;

	return default;
end;

function rw.config:Register(key, default, modifyFromMenu)
	stored[key] = {_DefaultValue = default, _ModifyFromMenu = (modifyFromMenu or true)};
end;