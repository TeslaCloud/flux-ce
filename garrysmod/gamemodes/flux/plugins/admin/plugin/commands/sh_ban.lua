--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("ban")
COMMAND.name = "Ban"
COMMAND.description = "#BanCMD_Description"
COMMAND.syntax = "#BanCMD_Syntax"
COMMAND.category = "administration"
COMMAND.arguments = 2
COMMAND.immunity = true
COMMAND.aliases = {"plyban"}

function COMMAND:OnRun(player, targets, duration, ...)
	local pieces = {...}
	local reason = "You have been banned."

	duration = fl.admin:InterpretBanTime(duration)

	if (!isnumber(duration)) then
		fl.player:Notify("This is not a valid duration!")

		return
	end

	if (#pieces > 0) then
		reason = string.Implode(" ", pieces)
	end

	for k, v in ipairs(targets) do
		fl.admin:Ban(v, duration, reason)
	end

	for k, v in ipairs(_player.GetAll()) do
		local time = "#for:;"..fl.lang:NiceTimeFull(v:GetNetVar("language"), time)

		if (duration <= 0) then time = "#permanently" end

		v:Notify(L("BanMessage", (IsValid(player) and player:Name()) or "Console", time, reason))
	end
end

COMMAND:Register()