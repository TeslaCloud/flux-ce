--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

library.New("theme", _G)
theme.activeTheme = theme.activeTheme or nil

local stored = theme.stored or {}
theme.stored = stored

function theme.GetStored()
	return stored
end

function theme.RegisterTheme(obj)
	if (obj.parent) then
		local parentTheme = stored[obj.parent:MakeID()]

		if (parentTheme) then
			local newObj = table.Copy(parentTheme)
			table.Merge(newObj, obj)
			obj = newObj
			obj.Base = parentTheme
		end
	end

	stored[obj.uniqueID] = obj
end

function theme.CreatePanel(panelID, parent, ...)
	local activeTheme = theme.activeTheme

	if (activeTheme and hook.Run("ShouldThemeCreatePanel", panelID, activeTheme) != false) then
		return activeTheme:CreatePanel(panelID, parent, ...)
	end
end

function theme.Hook(id, ...)
	local activeTheme = theme.activeTheme

	if (isstring(id) and activeTheme and activeTheme[id]) then
		local result = {pcall(activeTheme[id], activeTheme, ...)}
		local success = result[1]
		table.remove(result, 1)

		if (!success) then
			ErrorNoHalt("[Rework] Theme hook '"..id.."' has failed to run!\n"..result[1].."\n")
		else
			return unpack(result)
		end
	end
end

theme.Call = theme.Hook

function theme.GetActiveTheme()
	return (theme.activeTheme and theme.activeTheme.uniqueID)
end

function theme.SetSound(key, value)
	if (theme.activeTheme) then
		theme.activeTheme:SetSound(key, value)
	end
end

function theme.GetSound(key, fallback)
	if (theme.activeTheme) then
		return theme.activeTheme:GetSound(key, fallback)
	end

	return fallback
end

function theme.SetColor(key, value)
	if (theme.activeTheme) then
		theme.activeTheme:SetColor(key, value)
	end
end

function theme.SetFont(key, value)
	if (theme.activeTheme) then
		theme.activeTheme:SetFont(key, value)
	end
end

function theme.GetColor(key, fallback)
	if (theme.activeTheme) then
		return theme.activeTheme:GetColor(key, fallback)
	end

	return fallback
end

function theme.GetFont(key, fallback)
	if (theme.activeTheme) then
		return theme.activeTheme:GetFont(key, fallback)
	end

	return fallback
end

function theme.SetOption(key, value)
	if (theme.activeTheme) then
		theme.activeTheme:SetOption(key, value)
	end
end

function theme.SetMaterial(key, value)
	if (theme.activeTheme) then
		theme.activeTheme:SetMaterial(key, value)
	end
end

function theme.GetMaterial(key, fallback)
	if (theme.activeTheme) then
		return theme.activeTheme:GetMaterial(key, fallback)
	end

	return fallback
end

function theme.GetOption(key, fallback)
	if (theme.activeTheme) then
		return theme.activeTheme:GetOption(key, fallback)
	end

	return fallback
end

function theme.FindTheme(id)
	return stored[id:MakeID()]
end

function theme.RemoveTheme(id)
	if (theme.FindTheme(id)) then
		stored[id] = nil
	end
end

function theme.LoadTheme(themeID, bIsReloading)
	local themeTable = theme.FindTheme(themeID)

	if (themeTable) then
		if (!bIsReloading and hook.Run("ShouldThemeLoad", themeTable) == false) then
			return
		end

		theme.activeTheme = themeTable

		if (!bIsReloading and theme.activeTheme.OnLoaded) then
			theme.activeTheme:OnLoaded()

			hook.Run("OnThemeLoaded", theme.activeTheme)
		end
	end
end

function theme.UnloadTheme()
	if (hook.Run("ShouldThemeUnload", theme.activeTheme) == false) then
		return
	end

	if (theme.activeTheme.OnUnloaded) then
		theme.activeTheme:OnUnloaded()

		hook.Run("OnThemeUnloaded", theme.activeTheme)
	end

	theme.activeTheme = nil
end

function theme.Reload()
	if (!theme.activeTheme) then return; end

	if ((theme.activeTheme.shouldReload == false) or hook.Run("ShouldThemeReload", theme.activeTheme) == false) then
		return
	end

	theme.LoadTheme(theme.activeTheme.uniqueID)

	theme.Hook("OnReloaded")
	hook.Run("OnThemeReloaded", theme.activeTheme)
end

do
	local themeHooks = {}

	function themeHooks:InitPostEntity()
		theme.LoadTheme("Factory")
	end

	function themeHooks:OnReloaded()
		theme.Reload()
	end

	plugin.AddHooks("rwThemeHooks", themeHooks)
end