--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

--[[
	The settings library allows developers to easily add clientside settings/options that can be
	saved and persist between a client's play sessions (even between different servers).
--]]
library.New("settings", fl)

-- The table that will contain all the setting tables.
local stored = fl.settings.stored or {}
fl.settings.stored = stored

-- The table that will contain all the category tables.
local categories = fl.settings.categories or {}
fl.settings.categories = categories

-- For creating a colormixer's RGB conVars.
local mixerColors = {"r", "g", "b", "a"}

-- We do this to gain control over this internal hook for use with plugin hooks.
fl.OldOnConVarChanged = fl.OldOnConVarChanged or cvars.OnConVarChanged
function cvars.OnConVarChanged(name, oldVal, newVal)
	hook.Run("OnConVarChanged", name, oldVal, newVal)

	return fl.OldOnConVarChanged(name, oldVal, newVal)
end

--[[
	Used to get all the stored setting tables.

	returns [table] The stored table containing all of the created setting tables.
--]]
function fl.settings:GetStored()
	return stored
end

--[[
	This is used to get the actual setting table to edit anything it contains.

	[string] id Used to find the convar for the setting, this id will be the same as the id used to create the setting.

	returns [table] The setting table if it exists, this will return nil if it doesn't.
--]]
function fl.settings:GetSetting(id)
	return stored[id]
end

--[[
	This is used to get the actual convar object of a setting to set or get values from it.

	[string] id Used to find the convar for the setting, this id will be the same as the id used to create the setting.

	returns [conVar] The convar object stored in the setting table, if both exist (returns nil if they don't).
--]]
function fl.settings:GetConVar(id)
	local setting = stored[id]

	if (setting) then
		return setting.conVar
	end
end

--[[
	Used to get the value of a setting's convar as a string (what it was stored as). This
	will return nil if there is no value stored.

	[string] id Used to find the convar for the setting, this id will be the same as the id used to create the setting.

	returns [string] The value of the convar as a string, or nil.
--]]
function fl.settings:GetValue(id)
	local conVar = self:GetConVar(id)

	if (conVar) then
		return conVar:GetString()
	end

	return ""
end

-- This is an alias of GetValue.
fl.settings.GetString = fl.settings.GetValue

--[[
	Used to get the value of a setting's convar as a boolean value (if possible). This will return false
	if the stored value is a false value, or not a bool at all.

	[string] id Used to find the convar for the setting, this id will be the same as the id used to create the setting.

	returns [bool] The value of the convar as a bool, or false.
--]]
function fl.settings:GetBool(id)
	return util.ToBool(self:GetValue(id))
end

--[[
	Used to get the value of a setting's convar as a number (if possible). This will return nil
	if the stored value isn't actually a number.

	[string] id Used to find the convar for the setting, this id will be the same as the id used to create the setting.

	returns [number] The value of the convar as a number.
--]]
function fl.settings:GetNumber(id)
	local value = self:GetValue(id)

	if (value) then
		local nValue = tonumber(value)

		if (nValue) then
			return nValue
		end
	end

	return 0
end

--[[
	Used to get the value of a color setting's convars as a color object (if possible). This will return a
	black color if the stored values can't be found.

	[string] id Used to find the convar for the setting, this id will be the same as the id used to create the setting.

	returns [color] The value of the setting as a color object.
--]]
function fl.settings:GetColor(id)
	local color = Color(0, 0, 0, 255)
	local setting = stored[id]

	if (istable(setting)) then
		if (istable(setting.conVar)) then
			for k, v in pairs(setting.conVar) do	
				color[k] = v:GetFloat()
			end
		end
	end

	return color
end

--[[
	Used to set the value of a setting's convar.

	[string] id Used to find the convar for the setting, this id will be the same as the id used to create the setting.
	[string/number/bool] value This will be converted to a string when stored for easy storage. Using the correct Get function
		will give the correct type of value back (ex. GetNumber for number, GetBool for bool, etc).
--]]
function fl.settings:SetValue(id, value)
	local conVar = self:GetConVar(id)

	if (conVar) then
		hook.Run("OnSettingSet", id, value, conVar)

		local oldValue = self:GetValue(id)

		if (oldValue != value) then
			hook.Run("OnSettingChanged", id, value, oldValue, conVar)
		end

		return conVar:SetString(tostring(value))
	end
end

--[[
	Used to add a setting item to the settings menu with a convar attached to it, this will create
	the category if it doesn't exist, the convar, and add the element to the settings menu. It is
	recommended you use the	alias for this function instead of the function itself.

	[string] category Used as the id for the category that you want to add. Set the actual display name in language files (ex. #Settings_id).
	[string] id This is used as the id for the setting, and the convar along with it (FL_ID) This will be forced to uppercase for the convar name.
		you will want to set the actual display name, as well as the description in the language files (ex. #Settings_id, #Settings_Desc_id). These will
		NOT be uppercase forced like the convar.
	[string/number/bool/color] default This is the value that the new convar will be created with as its value. This will NOT change the value of the convar for someone
		who already has the convar created and saved. (If they've had the convar created in a previous play session).
	[bool] bShouldSave This will determine whether or not the convar value will persist through play sessions, lookup CreateClientConVar on gmod wiki for more information.
	[bool] bShared This will determine whether not the client's convar can be accessed by the server, lookup CreateClientConVar on gmod wiki for more information.
	[string] type This will determine what type of menu element will be added to the settings menu for this setting (ex. checkBox, numSlider, textEntry, comboBox, colorMixer).
	[table] info This contains the info to be used in creating the menu element in the settings menu for this setting.
	[table] callbacks This table contains all the callbacks that you want to be called when the setting's convar value changes. Look up cvars.AddChangeCallback on gmod
		wiki for more information. each table entry should contain a 'callback' entry, and optionally an 'identifier' entry.
	[function] visibleCallback This function will be called when the setting is added to see if the client should be able to use the setting in the settings menu
		(ex a user should not see admin-specific settings).

	returns [table] The created setting table.
--]]
function fl.settings:AddSetting(category, id, default, bShouldSave, bShared, type, info, callbacks, visibleCallback)
	local name = "FL_"..string.upper(id)
	local bExists = istable(stored[id])

	stored[id] = {
		id = id,
		category = category,
		type = type,
		info = info,
		callback = visibleCallback
	}

	if (type == "DColorMixer") then
		stored[id].conVar = {}

		if (!IsColor(default)) then
			default = Color(0, 0, 0, 255)
		end

		for k, v in ipairs(mixerColors) do
			stored[id].conVar[v] = CreateClientConVar(name.."_"..string.upper(v), tostring(default[v]), bShouldSave, bShared)
		end
	else
		stored[id].conVar = CreateClientConVar(name, tostring(default), bShouldSave, bShared)
	end

	if (istable(callbacks) and !bExists) then
		for k, v in pairs(callbacks) do
			if (isfunction(v)) then
				cvars.AddChangeCallback(name, v)
			else
				fl.core:Print("ERROR: No callback supplied")
			end
		end
	end

	if (isstring(category)) then
		if (!categories[category]) then
			self:AddCategory(category, nil, stored[id])
		else
			self:AddToCategory(category, stored[id])
		end
	end

	return stored[id]
end

-- Alias of AddSetting, used to easily add a checkbox item to the settings menu with convar linked to it.
function fl.settings:AddCheckBox(category, id, default, visibleCallback, callbacks, info, bShouldSave, bShared)
	return self:AddSetting(category, id, default, bShouldSave, bShared, "DCheckBox", info, callbacks, visibleCallback)
end

-- Alias of AddSetting, used to easily add a number slider item to the settings menu with convar linked to it.
function fl.settings:AddNumSlider(category, id, default, info, visibleCallback, callbacks, bShouldSave, bShared)
	return self:AddSetting(category, id, default, bShouldSave, bShared, "DNumSlider", info, callbacks, visibleCallback)
end

-- Alias of AddSetting, used to easily add a text entry item to the settings menu with convar linked to it.
function fl.settings:AddTextEntry(category, id, default, visibleCallback, callbacks, bShouldSave, bShared)
	return self:AddSetting(category, id, default, bShouldSave, bShared, "DTextEntry", nil, callbacks, visibleCallback)
end

-- Alias of AddSetting, used to easily add a combo box item to the settings menu with convar linked to it.
function fl.settings:AddComboBox(category, id, default, info, visibleCallback, callbacks, bShouldSave, bShared)
	return self:AddSetting(category, id, default, bShouldSave, bShared, "DComboBox", info, callbacks, visibleCallback)
end

-- Alias of AddSetting, used to easily add a color mixer item to the settings menu with convar linked to it.
function fl.settings:AddColorMixer(category, id, default, info, visibleCallback, callbacks, bShouldSave, bShared)
	return self:AddSetting(category, id, default, bShouldSave, bShared, "DColorMixer", info, callbacks, visibleCallback)
end

--[[
	This is used to to create a category to be displayed in the settings menu.

	[string] category Used as the id for the category that you want to add. Set the actual display name in language files (ex. #Settings_id).
	[string] icon Whatever material or url to be used for the icon displayed in the settings menu.
	[table] setting The initial setting to add to the category, used internally.
--]]
function fl.settings:AddCategory(category, icon, setting)
	local catTable = {
		id = category,
		icon = icon,
		settings = {}
	}

	if (setting) then
		catTable.settings[setting.id] = setting
	end

	categories[category] = catTable
end

--[[
	Adds a setting to a category table so we can easily get all settings in a category.

	[table] setting The setting table to add to the category table.
	[string] category The category id for the setting to be added to, will create the category if it doesn't exist.
--]]
function fl.settings:AddToCategory(category, setting)
	local catTable = categories[category]

	if (catTable) then
		catTable.settings[setting.id] = setting
	end
end

--[[
	This is used to get a category table by the id it was created with.

	[string] category This is the id that we search with to find the category table.

	returns [table] The category table if found, will return nil if not found.
--]]
function fl.settings:GetCategory(category)
	return categories[category]
end

--[[
	This is used to get a table containing all the currently created category tables.

	returns [table] This contains all of the current categories.
--]]
function fl.settings:GetCategories()
	return categories
end

--[[
	This is used to get all the currently created category tables in an
	number indexed table.

	[function] sortFunction This is an optional callback you can add to sort the indexed table
		before you get it from this function. Look up table.sort on gmod wiki for more information.

	returns [table] This contains all of the current categories in a number indexed table.
--]]
function fl.settings:GetIndexedCategories(sortFunction)
	local sorted = {}

	for k, v in pairs(categories) do
		sorted[#sorted + 1] = v
	end

	if (isfunction(sortFunction)) then
		table.sort(sorted, sortFunction)
	end

	return sorted
end

--[[
	This is used by the settings menu to quickly and easily get all the settings in
	a category, stored in the 'setting' entry of the category table.

	[string] category This is the id of the category that we search with to find the category
		table, and therefore the settings contained in that table.

	returns [table] The table containing all the settings that are part of the specified category, will be nil
		if the category doesn't exist, or an empty table if there are no settings stored in the category table.
--]]
function fl.settings:GetCategorySettings(category)
	local catTable = categories[category]
	local setList = {}

	if (catTable) then
		for k, v in pairs(catTable.settings) do
			setList[#setList + 1] = v
		end
	end

	return setList
end

-- Not going to document these yet as these might as well be placeholders for testing while I build the frontend.
fl.settings:AddCheckBox("AdminESP", "EnableAdminESP", false, function()
	return LocalPlayer():IsAdmin()
end)
fl.settings:AddColorMixer("Theme", "TextColor", Color(255, 255, 255, 255))
fl.settings:AddColorMixer("Theme", "MenuBackColor", Color(40, 40, 40, 150))
fl.settings:AddCheckBox("Theme", "UseTabDash", false, nil,
	{
		callback = function(name, oldValue, newValue)
			if (util.ToBool(newValue)) then
//				theme.SetPanel("TabMenu", "flTabDash")
			else
//				theme.SetPanel("TabMenu", "flTabClassic")
			end

			local tabMenu = fl.tabMenu

			if (IsValid(tabMenu)) then
				tabMenu:CloseMenu()

				fl.tabMenu = theme.CreatePanel("TabMenu", nil, "flTabDash")
				fl.tabMenu:MakePopup()
				fl.tabMenu.heldTime = CurTime() + 0.3
			end
		end
	}
)
fl.settings:AddColorMixer("Dashboard", "BackgroundColor", Color(0, 0, 0, 255), nil, function()
	return false //(theme.GetPanel("TabMenu") == "flTabDash")
end)
fl.settings:AddComboBox("Dashboard", "FitType", "", {
		["fill"] = "#Settings_Fit_Fill",
		["fit"] = "#Settings_Fit_Fit",
		["tiled"] = "#Settings_Fit_Tiled",
		["center"] = "#Settings_Fit_Center"
	},
	function()
		return false //(theme.GetPanel("TabMenu") == "flTabDash")
	end,
	{
		callback = function(name, oldValue, newValue)
			local tabMenu = fl.tabMenu

			if (IsValid(tabMenu)) then
				tabMenu:SetBackImage(fl.settings:GetString("BackgroundURL"), newValue)
			end
		end
	}
)
fl.settings:AddTextEntry("Dashboard", "BackgroundURL", "",
	function()
		return false //(theme.GetPanel("TabMenu") == "flTabDash")
	end,
	{
		callback = function(name, oldValue, newValue)
			local tabMenu = fl.tabMenu

			if (IsValid(tabMenu)) then
				tabMenu:SetBackImage(newValue, fl.settings:GetString("FitType"))
			end
		end
	}
)

fl.settings:AddCheckBox("HUD", "DrawBars", true)
fl.settings:AddCheckBox("HUD", "DrawBarText", true)


--[[ -- For example on how to add a number slider.
fl.settings:AddNumSlider("Test", "TestNumSlider", "", {
	min = 5,
	max = 20,
	decimals = 5
})
fl.settings:AddNumSlider("Test", "TestNumSlider2", "", {
	min = 0,
	max = 100,
	decimals = 0
})
--]]