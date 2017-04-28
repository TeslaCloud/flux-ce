--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library = library or {}
library.stored = library.stored or {}

-- A function to print a prefixed message.
function fl.Print(strMessage)
	if (!istable(strMessage)) then
		Msg("[Flux] ")
		print(strMessage)
	else
		print("[Flux] Printing table:")
		PrintTable(strMessage)
	end
end

-- A function to print developer message.
function fl.DevPrint(strMessage)
	if (fl.Devmode) then
		Msg("[Flux:")
		MsgC(Color(175, 0, 0), "Dev")
		Msg("] ")
		MsgC(Color(200, 200, 200), strMessage)
		Msg("\n")
	end
end

file.OldWrite = file.OldWrite or file.Write

function file.Write(strFileName, strContent)
	local exploded = string.Explode("/", strFileName)
	local curPath = ""

	for k, v in ipairs(exploded) do
		if (string.GetExtensionFromFilename(v) != nil) then
			break
		end

		curPath = curPath..v.."/"

		if (!file.Exists(curPath, "DATA")) then
			file.CreateDir(curPath)
		end
	end

	return file.OldWrite(strFileName, strContent)
end

-- A function to create a new library.
function library.New(strName, tParent)
	tParent = tParent or _G

	tParent[strName] = tParent[strName] or {}

	return tParent[strName]
end

-- A function to get an existing library.
function library.Get(strName, tParent)
	tParent = tParent or _G

	return tParent[strName] or library.New(strName, tParent)
end

-- Set library table's Metatable so that we can call it like a function.
setmetatable(library, {__call = function(tab, strName, tParent) return tab.Get(strName, tParent) end})

-- A function to create a new class. Supports constructors and inheritance.
function library.NewClass(strName, tParent, CExtends)
	local class = {
		-- Same as "new ClassName" in C++
		__call = function(obj, ...)
			local newObj = {}

			-- Set new object's meta table and copy the data from original class to new object.
			setmetatable(newObj, obj)
			table.SafeMerge(newObj, obj)

			-- If there is a base class, call their constructor.
			if (obj.BaseClass) then
				pcall(obj.BaseClass, newObj, ...)
			end

			-- If there is a constructor - call it.
			if (obj[strName]) then
				local success, value = pcall(obj[strName], newObj, ...)

				if (!success) then
					ErrorNoHalt("["..strName.."] Class constructor has failed to run!\n")
					ErrorNoHalt(value.."\n")
				end
			end

			-- Return our newly generated object.
			return newObj
		end
	}

	-- If this class is based off some other class - copy it's parent's data.
	if (istable(CExtends)) then
		table.SafeMerge(class, CExtends)
	end

	-- Create the actual class table.
	local obj = library.New(strName, (tParent or _G))
	obj.ClassName = strName
	obj.BaseClass = CExtends or false

	return setmetatable((tParent or _G)[strName], class)
end

function Class(strName, CExtends, tParent)
	return library.NewClass(strName, tParent, CExtends)
end

-- Alias because class could get easily confused with player class.
Meta = Class

-- Also make an alias that looks like other programming languages.
class = Class

--[[
	Example usage:

	local obj = new "className"
	local obj = new("className", 1, 2, 3)
--]]
function New(className, ...)
	return (_G[className] and _G[className](unpack(...)))
end

new = New

function fl.GetSchemaFolder()
	if (SERVER) then
		return fl.schema
	else
		return fl.sharedTable.schemaFolder or "flux"
	end
end

function fl.Serialize(tTable)
	if (istable(tTable)) then
		local bSuccess, value = pcall(pon.encode, tTable)

		if (!bSuccess) then
			bSuccess, value = pcall(util.TableToJSON, tTable)

			if (!bSuccess) then
				ErrorNoHalt("[Flux] Failed to serialize a table!\n")
				ErrorNoHalt(value.."\n")
				debug.Trace()

				return ""
			end
		end

		return value
	else
		print("[Flux] You must serialize a table, not "..type(tTable).."!")

		return ""
	end
end

function fl.Deserialize(strData)
	if (isstring(strData)) then
		local bSuccess, value = pcall(pon.decode, strData)

		if (!bSuccess) then
			bSuccess, value = pcall(util.JSONToTable, strData)

			if (!bSuccess) then
				ErrorNoHalt("[Flux] Failed to deserialize a string!\n")
				ErrorNoHalt(value.."\n")
				debug.Trace()

				return {}
			end
		end

		return value
	else
		print("[Flux] You must deserialize a string, not "..type(strData).."!")

		return {}
	end
end

function fl.IncludeSchema()
	if (SERVER) then
		return plugin.IncludeSchema()
	else
		timer.Create("SchemaLoader", 0.04, 0, function()
			if (fl.sharedTable and fl.sharedTableReceived) then
				timer.Remove("SchemaLoader")
				plugin.IncludeSchema()
				netstream.Start("ClientIncludedSchema", true)
			end
		end)
	end
end

function fl.IncludePlugins(strFolder)
	if (SERVER) then
		return plugin.IncludePlugins(strFolder)
	else
		timer.Create("PluginLoader", 0.04, 0, function()
			if (fl.sharedTable and fl.sharedTableReceived) then
				timer.Remove("PluginLoader")
				plugin.IncludePlugins(strFolder)
			end
		end)
	end
end

-- A function to get the schema gamemode info.
function fl.GetSchemaInfo()
	if (SERVER) then
		if (fl.SchemaInfo) then return fl.SchemaInfo end

		local schemaFolder = string.lower(fl:GetSchemaFolder())
		local schemaData = util.KeyValuesToTable(
			fileio.Read("gamemodes/"..schemaFolder.."/"..schemaFolder..".txt")
		)

		if (!schemaData) then
			schemaData = {}
		end

		if (schemaData["Gamemode"]) then
			schemaData = schemaData["Gamemode"]
		end

		fl.SchemaInfo = {}
			fl.SchemaInfo["name"] = schemaData["title"] or "Undefined"
			fl.SchemaInfo["author"] = schemaData["author"] or "Undefined"
			fl.SchemaInfo["description"] = schemaData["description"] or "Undefined"
			fl.SchemaInfo["version"] = schemaData["version"] or "Undefined"
			fl.SchemaInfo["folder"] = schemaFolder:gsub("/schema", "")
		return fl.SchemaInfo
	else
		return fl.sharedTable.schemaInfo
	end
end

if (SERVER) then
	fl.sharedTable.schemaInfo = fl.GetSchemaInfo()
end