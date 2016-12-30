--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("config", _G);

local stored = config.stored or {};
config.stored = stored;

local cache = {};

if (SERVER) then
	function config.Set(key, value, bIsHidden)
		if (key != nil) then
			stored[key] = stored[key] or {};
			stored[key]._Value = value;
			stored[key].hidden = bIsHidden or false;

			if (!stored[key].hidden) then
				netstream.Start(nil, "config_setvar", key, stored[key]);
			end;

			cache[key] = value;
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
		cache[key] = value;
	end);
end;

function config.Get(key, default)
	if (cache[key]) then
		return cache[key];
	end;

	if (stored[key] != nil) then
		if (stored[key]._Value != nil) then
			cache[key] = stored[key]._Value;
			return stored[key]._Value;
		elseif (stored[key].DefaultValue != nil) then
			cache[key] = stored[key]._DefaultValue;
			return stored[key]._DefaultValue;
		end;
	end;

	cache[key] = default;
	return default;
end;

function config.Register(key, default, modifyFromMenu)
	stored[key] = {_DefaultValue = default, _ModifyFromMenu = (modifyFromMenu or true)};
end;