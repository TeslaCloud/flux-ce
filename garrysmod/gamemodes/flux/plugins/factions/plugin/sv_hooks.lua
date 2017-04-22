--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flFactions:PostPlayerSpawn(player)
	local playerFaction = player:GetFaction()

	if (playerFaction) then
		player:SetTeam(playerFaction.teamID or 1)
	end
end