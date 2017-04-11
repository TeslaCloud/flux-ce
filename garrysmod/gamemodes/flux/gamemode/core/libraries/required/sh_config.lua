--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

-- This library is for serverside configs only!
-- For clientside configs, see cl_settings.lua!

library.New("config", _G)

local stored = config.stored or {}
config.stored = stored

local cache = {}

if (SERVER) then
	function config.Set(key, value, bIsHidden)
		if (key != nil) then
			if (!stored[key]) then
				stored[key] = {}

				if (PLUGIN) then
					stored[key].addedBy = PLUGIN:GetName()
				elseif (Schema) then
					stored[key].addedBy = "Schema"
				else
					stored[key].addedBy = "Flux"
				end
			end

			stored[key].value = value
			stored[key].hidden = bIsHidden or false

			if (!stored[key].hidden) then
				netstream.Start(nil, "config_setvar", key, stored[key])
			end

			cache[key] = value
		end
	end

	local playerMeta = FindMetaTable("Player")

	function playerMeta:SendConfig()
		for k, v in pairs(stored) do
			if (!v.hidden) then
				netstream.Start(self, "config_setvar", k, v.value)
			end
		end

		player.flHasSentConfig = true
	end
else
	local menuItems = config.menuItems or {}
	config.menuItems = menuItems

	function config.AddToMenu(key, name, description, dataType, data)
		if (!key) then return end

		menuItems[key] = menuItems[key] or {}
		menuItems[key].name = name or key
		menuItems[key].description = description or "This config has no description set."
		menuItems[key].type = dataType -- valid types: table, number (or num), string (or text), bool (or boolean)
		menuItems[key].data = data or {}
	end

	function config.GetMenuKeys()
		return menuItems
	end

	function config.GetMenuKey(key)
		return menuItems[key]
	end

	netstream.Hook("config_setvar", function(key, value)
		if (key == nil) then return end

		print(key, value)

		stored[key] = stored[key] or {}
		stored[key].value = value
		cache[key] = value
	end)
end

function config.Get(key, default)
	if (cache[key]) then
		return cache[key]
	end

	if (stored[key] != nil) then
		if (stored[key].value != nil) then
			cache[key] = stored[key].value

			return stored[key].value
		end
	end

	cache[key] = default

	return default
end

function config.GetAll()
	return stored
end

function config.GetCache()
	return cache
end