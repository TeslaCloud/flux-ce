--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

/**
* Library: library
* Description: Provides function for library and class creation, manipulation and instantiation.
**/
library = library or {}
library.stored = library.stored or {}

/**
* Function: fl.Print (any message)
* Description: Prints a message to the console.
* Argument: any message - Any variable to be printed. If it's table, PrintTable will automatically be used.
*
* Returns:
* nil
**/
function fl.Print(message)
	if (!istable(message)) then
		Msg("[Flux] ")
		print(message)
	else
		print("[Flux] Printing table:")
		PrintTable(message)
	end
end

/**
* Function: fl.DevPrint (string message)
* Description: Prints a developer message to console. The message is prefixed with a colored [Flux:Dev].
* Argument: string message - Message to be printed as a developer comment.
*
* Returns:
* nil
**/
function fl.DevPrint(strMessage)
	if (fl.Devmode) then
		Msg("[Flux:")
		MsgC(Color(175, 0, 0), "Dev")
		Msg("] ")
		MsgC(Color(200, 200, 200), strMessage)
		Msg("\n")
	end
end

/**
* Function: file.Write (string fileName, string fileContents)
* Description: Writes a file to the data/ folder. This detour adds the ability for it to create all of the folders leading to the file path automatically.
* Argument: string fileName - The name of the file to write. See http://wiki.garrysmod.com/page/file/Write for futher documentation.
* Argument: string fileContents - Contents of the file as a NULL-terminated string.
*
* Returns:
* nil
**/
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

/**
* Function: library.New (string name, table parent = _G)
* Description: Creates a library inside the parent table.
* Argument: string name - The name of the library. Must comply with Lua variable name requirements.
* Argument: table parent (default: _G) - The parent table to put the library into.
*
* Returns:
* table - The created library.
**/
function library.New(strName, tParent)
	tParent = tParent or _G

	tParent[strName] = tParent[strName] or {}

	return tParent[strName]
end

-- Set library table's Metatable so that we can call it like a function.
setmetatable(library, {__call = function(tab, strName, tParent) return tab.Get(strName, tParent) end})

/**
* Function: library.NewClass (string name, table parent = _G, class baseClass = nil)
* Description: Creates a new class. Supports constructors and inheritance.
* Argument: string name - The name of the library. Must comply with Lua variable name requirements.
* Argument: table parent (default: _G) - The parent table to put the class into.
* Argument: class baseClass (default: nil) - The base class this new class should extend.
*
* Alias: Class (string name, class baseClass = nil, table parent = _G)
* Alias: class (string name, class baseClass = nil, table parent = _G)
*
* Returns:
* table - The created class.
**/
function library.NewClass(strName, tParent, CExtends)
	local class = {
		-- Same as "new ClassName" in C++
		__call = function(obj, ...)
			local newObj = {}

			-- Set new object's meta table and copy the data from original class to new object.
			setmetatable(newObj, obj)
			table.SafeMerge(newObj, obj)

			-- If there is a base class, call their constructor.
			local baseClass = obj.BaseClass
			local hasBaseclass = true

			while (istable(baseClass) and hasBaseclass) do
				if (isfunction(baseClass[baseClass.ClassName])) then
					try {
						baseClass[baseClass.ClassName], newObj, ...
					} catch {
						function(exception)
							ErrorNoHalt("[Flux] Base class constructor has failed to run!\n"..tostring(exception.."\n"))
						end
					}
				end

				if (baseClass.BaseClass and baseClass.ClassName != baseClass.BaseClass.ClassName) then
					baseClass = baseClass.BaseClass
				else
					hasBaseclass = false
				end
			end

			-- If there is a constructor - call it.
			if (obj[strName]) then
				local success, value = pcall(obj[strName], newObj, ...)

				if (!success) then
					ErrorNoHalt("["..strName.."] Class constructor has failed to run!\n")
					ErrorNoHalt(value.."\n")
				end
			end

			newObj.IsValid = function() return true end

			-- Return our newly generated object.
			return newObj
		end
	}

	-- If this class is based off some other class - copy it's parent's data.
	if (istable(CExtends)) then
		local copy = table.Copy(CExtends)
		local merged = table.SafeMerge(copy, class)

		if (isfunction(CExtends.OnExtended)) then
			try {
				CExtends.OnExtended, copy, merged
			} catch {
				function(exception)
					ErrorNoHalt("[Flux] OnExtended class hook has failed to run!\n"..tostring(exception.."\n"))
				end
			}
		end

		class = merged
	end

	-- Create the actual class table.
	local obj = library.New(strName, (tParent or _G))
	obj.ClassName = strName
	obj.BaseClass = CExtends or false

	library.lastClass = {name = strName, parent = (tParent or _G)}

	return setmetatable((tParent or _G)[strName], class)
end

-- Aliases
function Class(strName, CExtends, tParent)
	return library.NewClass(strName, tParent, CExtends)
end

class = Class

/**
* Function: extends (class baseClass)
* Description: Sets the base class of the class that is currently being created.
* Argument: class baseClass - The base class to extend.
*
* Alias: implements
* Alias: inherits
*
* Returns:
* bool - Whether or not did the extension succeed.
**/
function extends(CBaseClass)
	if (isstring(CBaseClass)) then
		CBaseClass = _G[CBaseClass]
	end

	if (istable(library.lastClass) and istable(CBaseClass)) then
		local obj = library.lastClass.parent[library.lastClass.name]
		local copy = table.Copy(CBaseClass)
		local merged = table.Merge(copy, obj)

		if (isfunction(CBaseClass.OnExtended)) then
			try {
				CBaseClass.OnExtended, copy, merged
			} catch {
				function(exception)
					ErrorNoHalt("[Flux] OnExtended class hook has failed to run!\n"..tostring(exception.."\n"))
				end
			}
		end

		obj = merged
		obj.BaseClass = CBaseClass

		hook.Run("OnClassExtended", obj, CBaseClass)

		library.lastClass.parent[library.lastClass.name] = obj
		library.lastClass = nil

		return true
	end

	return false
end

--[[
	class "SomeClass" extends SomeOtherClass
	class "SomeClass" extends "SomeOtherClass"
--]]

-- Aliases for people who're hell bent on clarity.
implements = extends
inherits = extends

/**
* Function: New (string className, ...)
* Description: Creates a new instance of the supplied class
* Argument: string className - The name of the class to create.
* Argument: vararg - Arguments to pass to the class constructor.
*
* Alias: new
*
* Returns:
* object - The instance of the supplied class. nil if class does not exist.
**/
function New(className, ...)
	if (istable(className)) then
		return className(...)
	end

	return (_G[className] and _G[className](unpack(...)))
end

--[[
	Example usage:

	local obj = new "className"
	local obj = new("className", 1, 2, 3)
--]]

new = New

do
	local actionStorage = fl.actionStorage or {}
	fl.actionStorage = actionStorage

	/**
	* Function: fl.RegisterAction (string id, function callback)
	* Description: Registers an action that can be assigned to a player.
	* Argument: string id - Identifier of the action.
	* Argument: function callback - Function to call when the action is executed.
	*
	* Returns:
	* nil
	**/
	function fl.RegisterAction(id, callback)
		actionStorage[id] = callback
	end

	/**
	* Function: fl.GetAction (string id)
	* Description: Retreives the action callback with the specified identifier.
	* Argument: string id - ID of the action to get the callback of.
	*
	* Returns:
	* function - The callback.
	**/
	function fl.GetAction(id)
		return actionStorage[id]
	end

	/**
	* Function: fl.GetAllActions ()
	* Description: Can be used to directly access the table storing all of the actions.
	*
	* Returns:
	* table - The actionStorage table.
	**/
	function fl.GetAllActions()
		return actionStorage
	end

	fl.RegisterAction("spawning")
	fl.RegisterAction("idle")
end

/**
* Function: fl.GetSchemaFolder ()
* Description: Gets the folder of the currently loaded schema.
*
* Returns:
* string - The folder of the currently loaded schema.
**/
function fl.GetSchemaFolder()
	if (SERVER) then
		return fl.schema
	else
		return fl.sharedTable.schemaFolder or "flux"
	end
end

/**
* Function: fl.Serialize (table toSerialize)
* Description: Converts a table into the string format.
* Argument: table toSerialize - Table to convert.
*
* Returns:
* string - pON-encoded table. If pON fails then JSON is returned.
**/
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

/**
* Function: fl.Deserialize (string toDeserialize)
* Description: Converts a string back into table. Uses pON at first, if it fails it falls back to JSON.
* Argument: string toDeserialize - String to convert.
*
* Returns:
* table - Decoded string.
**/
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

/**
* Function: fl.IncludeSchema ()
* Description: Includes the currently loaded schema's files. Performs deferred load on client.
*
* Returns:
* nil
**/
function fl.IncludeSchema()
	if (SERVER) then
		return plugin.IncludeSchema()
	else
		timer.Create("SchemaLoader", 0.04, 0, function()
			if (fl.sharedTable and fl.sharedTableReceived) then
				timer.Remove("SchemaLoader")
				plugin.IncludeSchema()
				netstream.Start("ClientIncludedSchema", true)

				hook.Run("FluxClientSchemaLoaded")
			end
		end)
	end
end

/**
* Function: fl.IncludePlugins (string folder)
* Description: Includes all of the plugins inside the folder. Includes files first, then folders. Does not handle plugin-inside-of-plugin scenarios.
* Argument: string folder - Folder relative to Lua's PATH (lua/, gamemodes/).
*
* Returns:
* nil
**/
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

/**
* Function: fl.GetSchemaInfo ()
* Description: Gets the table containing all of the information about the currently loaded schema.
*
* Returns:
* table - The schema info table.
**/
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
			fl.SchemaInfo["folder"] = string.gsub(schemaFolder, "/schema", "")
		return fl.SchemaInfo
	else
		return fl.sharedTable.schemaInfo
	end
end

if (SERVER) then
	fl.sharedTable.schemaInfo = fl.GetSchemaInfo()
end