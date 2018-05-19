--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

-- This library is for serverside configs only!
-- For clientside configs, see cl_settings.lua!

library.New "config"

local stored = config.stored or {}
config.stored = stored

local cache = {}

function config.GetAll()
	return stored
end

function config.GetCache()
	return cache
end

if (SERVER) then
	function config.Set(key, value, bIsHidden, nFromConfig)
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

				if (isnumber(nFromConfig)) then
					if (nFromConfig == CONFIG_FLUX) then
						stored[key].addedBy = "Flux Config"
					elseif (nFromConfig == CONFIG_SCHEMA) then
						stored[key].addedBy = "Schema Config"
					elseif (PLUGIN and nFromConfig == CONFIG_PLUGIN) then
						stored[key].addedBy = PLUGIN:GetName().." Config"
					end
				end
			end

			stored[key].value = value

			if (stored[key].hidden == nil or bIsHidden != nil) then
				stored[key].hidden = bIsHidden or false
			end

			if (!stored[key].hidden) then
				netstream.Start(nil, "Flux::Config::SetVar", key, stored[key].value)
			end

			cache[key] = value
		end
	end

	local playerMeta = FindMetaTable("Player")

	function playerMeta:SendConfig()
		for k, v in pairs(stored) do
			if (!v.hidden) then
				netstream.Start(self, "Flux::Config::SetVar", k, v.value)
			end
		end

		player.flHasSentConfig = true
	end
else
	local menuItems = config.menuItems or {}
	config.menuItems = menuItems

	function config.Set(key, value)
		if (key != nil) then
			if (!stored[key]) then
				stored[key] = {}
			end

			stored[key].value = value
			cache[key] = value
		end
	end

	function config.CreateCategory(id, name, description)
		id = id or "other"

		menuItems[id] = {
			category = {name = name or "Other", description = description or ""},
			AddKey = function(key, name, description, dataType, data)
				config.AddToMenu(id, key, name, description, dataType, data)
			end,
			AddSlider = function(key, name, description, data)
				config.AddToMenu(id, key, name, description, "number", data)
			end,
			AddTableEditor = function(key, name, description, data)
				config.AddToMenu(id, key, name, description, "table", data)
			end,
			AddTextBox = function(key, name, description, data)
				config.AddToMenu(id, key, name, description, "string", data)
			end,
			AddCheckbox = function(key, name, description, data)
				config.AddToMenu(id, key, name, description, "bool", data)
			end,
			AddDropdown = function(key, name, description, data)
				config.AddToMenu(id, key, name, description, "dropdown", data)
			end,
			configs = {}
		}

		return menuItems[id]
	end

	function config.GetCategory(id)
		return menuItems[id]
	end

	function config.AddToMenu(category, key, name, description, dataType, data)
		if (!category or !key) then return end

		menuItems[category] = menuItems[category] or {}
		menuItems[category].configs = menuItems[category].configs or {}

		table.insert(menuItems[category].configs, {
			name = name or key,
			description = description or "This config has no description set.",
			type = dataType,
			data = data or {}
		})
	end

	function config.GetMenuKeys()
		return menuItems
	end

	netstream.Hook("Flux::Config::SetVar", function(key, value)
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

-- Config interpreter.
-- Please note that it's really slow and should never be used more than
-- once in a while.
do
	local countCharacter = string.CountCharacter
	local isNumber = string.IsNumber
	local buildTableFromString = util.BuildTableFromString

	local function buildWordFromTable(tab, idx, len)
		local word = ""

		for i = idx, idx + len - 1 do
			local char = tab[i] or ""

			word = word..char
		end

		return word
	end

	local function dataTypeToValue(type, value)
		if (type == "string") then
			if (value == "nil") then
				return nil
			else
				return tostring(value)
			end
		elseif (type == "number") then
			return tonumber(value)
		elseif (type == "table") then
			return buildTableFromString(value)
		end
	end

	function config.ConfigToTable(strConfigFile)
		local keyValues = {}
		local characters = string.Explode("", strConfigFile)
		local lines = string.Explode("\n", strConfigFile)
		local skip = ""
		local nSkip = 0
		local read = ""
		local buffer = ""
		local curKey = nil
		local curVal = nil
		local curDataType = "string"
		local curLine = 1

		for k, v in ipairs(characters) do
			local nextChar = characters[k + 1] or ""
			local prevChar = characters[k - 1] or ""

			if (v == "\n") then
				curLine = curLine + 1
			end

			if (nSkip > 0) then
				nSkip = nSkip - 1

				continue
			end

			if (skip != "") then
				local skipLen = skip:utf8len()
				local curWord = buildWordFromTable(characters, k, skipLen)

				if (curWord == skip) then
					skip = ""
					nSkip = skipLen - 1
				end

				continue
			end

			-- Skip the comments.
			if (read != "\"") then
				if (v == "/" and nextChar == "/") then
					skip = "\n"

					continue
				elseif (v == "/" and nextChar == "*") then
					skip = "*/"

					continue
				end
			end

			if (string.find(buffer, "\n")) then
				buffer = ""
			end

			if (read == "") then
				if (v == "{") then
					if (!string.find(strConfigFile, "}")) then
						ErrorNoHalt("[Flux:Config] Config file syntax error: '}' expected to close '{' at line "..curLine.."!\n")

						return {}
					end

					read = "}"
					curDataType = "table"

					continue
				elseif (isNumber(v)) then
					curDataType = "number"
				elseif (v == "\"") then
					if (countCharacter(lines[curLine], "\"") % 2 != 0) then
						ErrorNoHalt("[Flux:Config] Config file syntax error: unfinished string at line "..curLine.."!\n")

						return {}
					end

					read = "\""
					curDataType = "string"

					continue
				end
			end

			-- Fix for table closures being in the final string.
			if (v == "}" and read != "}" and read != "\"") then
				continue
			end

			-- While we're not hitting the stop mark, continue filling in the buffer.
			if (read != "") then
				local readLen = read:utf8len()
				local curWord = buildWordFromTable(characters, k, readLen)
				local readHit = false

				if (read == " " or read == "\t") then
					if (curWord == " " or curWord == "\t") then
						readHit = true
					end
				else
					if (curWord == read) then
						if (read == "\"") then
							if (prevChar != "\\") then
								readHit = true
							end
						else
							readHit = true
						end
					end
				end

				if (k == #characters) then
					readHit = true
				end

				if (!readHit) then
					buffer = buffer..v

					continue
				else
					read = ""

					-- Fix table interpreting.
					if (v == "}") then
						buffer = buffer..v
					end

					local val = dataTypeToValue(curDataType, buffer)

					if (curKey == nil) then
						curKey = val
					elseif (curVal == nil) then
						keyValues[curKey] = val

						curKey = nil
						curVal = nil
					end

					buffer = ""
					curDataType = "string"

					continue
				end
			end

			if (v == "\t" or v == "\n") then
				continue
			end

			buffer = buffer..v

			if (curKey == nil) then
				read = " "
			else
				read = "\n"
			end
		end

		return keyValues
	end
end

function config.Import(strFileContents, nFromConfig)
	if (!isstring(strFileContents) or strFileContents == "") then return end

	local cfgTable = config.ConfigToTable(strFileContents)

	for k, v in pairs(cfgTable) do
		if (k != "depends" and plugin.Call("ShouldConfigImport", k, v) == nil) then
			config.Set(k, v, nil, nFromConfig)
		end
	end

	return cfgTable
end
