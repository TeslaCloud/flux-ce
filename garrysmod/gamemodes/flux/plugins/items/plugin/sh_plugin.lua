--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetAlias("flItems")

util.Include("cl_hooks.lua")
util.Include("sv_hooks.lua")
util.Include("sh_enums.lua")

function flItems:OnPluginLoaded()
	plugin.AddExtra("items")
	plugin.AddExtra("items/bases")

	util.IncludeDirectory(self:GetFolder().."/plugin/items/bases")
	item.IncludeItems(self:GetFolder().."/plugin/items/")
end

function flItems:PluginIncludeFolder(extra, folder)
	if (extra == "items") then
		item.IncludeItems(folder.."/items/")

		return true
	end
end