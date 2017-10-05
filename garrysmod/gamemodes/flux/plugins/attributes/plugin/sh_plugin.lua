--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetAlias("flAttributes")

util.Include("cl_hooks.lua")
util.Include("sv_hooks.lua")
util.Include("sh_enums.lua")

function flAttributes:OnPluginLoaded()
	plugin.AddExtra("attributes")

	attributes.IncludeAttributes(self:GetFolder().."/plugin/attributes/")
end

function flAttributes:PluginIncludeFolder(extra, folder)
	if (extra == "attributes") then
		attributes.IncludeAttributes(folder.."/attributes/")

		return true
	end
end