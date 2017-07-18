--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("forcegetup")
COMMAND.name = "ForceGetUp"
COMMAND.description = "Forces a player to get up."
COMMAND.syntax = "<target> [number GetUpTime]"
COMMAND.category = "roleplay"
COMMAND.arguments = 1
COMMAND.playerArg = 1
COMMAND.aliases = {"forcegetup", "plygetup"}

function COMMAND:OnRun(player, target, delay)
	delay = math.Clamp(delay or 0, 0, 60)
	target = target[1]

	if (IsValid(target) and target:Alive() and target:IsRagdolled()) then
		target:SetRagdollState(RAGDOLL_FALLENOVER)

		player:Notify(target:Name().." has been unragdolled!")

		timer.Simple(delay, function()
			target:SetRagdollState(RAGDOLL_NONE)
		end)
	else
		player:Notify("This player cannot be unragdolled right now!")
	end
end

COMMAND:Register()