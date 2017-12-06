--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

util.Include("cl_hooks.lua")
util.Include("sv_plugin.lua")
util.Include("sv_hooks.lua")
util.Include("sh_enums.lua")

function PLUGIN:PlayerSetupDataTables(player)
	player:DTVar("Int", INT_RAGDOLL_STATE, "RagdollState")
	player:DTVar("Entity", ENT_RAGDOLL, "RagdollEntity")
end

function PLUGIN:CalcView(player, origin, angles, fov)
	local view = GAMEMODE.BaseClass:CalcView(player, origin, angles, fov) or {}
	local entity = player:GetDTEntity(ENT_RAGDOLL)

	if (!player:ShouldDrawLocalPlayer() and IsValid(entity) and entity:IsRagdoll()) then
		local index = entity:LookupAttachment("eyes")

		if (index) then
			local data = entity:GetAttachment(index)

			if (data) then
				view.origin = data.Pos
				view.angles = data.Ang
			end

			return view
		end
	end
end