--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("fall")
COMMAND.name = "Fall"
COMMAND.description = "Fall down on the ground."
COMMAND.syntax = "[number GetUpTime]"
COMMAND.category = "roleplay"
COMMAND.aliases = {"fallover", "charfallover"}
COMMAND.noConsole = true

function COMMAND:OnRun(player, delay)
	if (isnumber(delay) and delay > 0) then
		delay = math.Clamp(delay or 0, 2, 60)
	end

	if (player:Alive() and !player:IsRagdolled()) then
		player:SetRagdollState(RAGDOLL_FALLENOVER)

		if (delay and delay > 0) then
			player:RunCommand("getup "..tostring(delay))
		end
	else
		player:Notify("You cannot do this right now!")
	end
end

COMMAND:Register()