--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetAlias("flParameters")

util.Include("cl_hooks.lua")
util.Include("sv_hooks.lua")
util.Include("sh_enums.lua")

function flParameters:OnPluginLoaded()
	plugin.AddExtra("parameters")

	parameters.IncludeParameters(self:GetFolder().."/plugin/parameters/")
end

function flParameters:PluginIncludeFolder(extra, folder)
	if (extra == "parameters") then
		parameters.IncludeParameters(folder.."/parameters/")

		return true
	end
end