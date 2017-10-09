--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("gag")
COMMAND.Name = "Gag"
COMMAND.Description = "Mute player's OOC chats."
COMMAND.Syntax = "<name> <duration> [reason]"
COMMAND.Category = "administration"
COMMAND.Arguments = 2
COMMAND.Immunity = true
COMMAND.Aliases = {"muteooc", "oocmute", "plygag"}

function COMMAND:OnRun(player, targets, duration, ...)
	local pieces = {...}
	local reason = "Muted for unspecified reason."

	duration = fl.admin:InterpretBanTime(duration)

	if (!isnumber(duration)) then
		player:Notify("'"..tostring(duration).."' could not be interpreted as duration!")

		return
	end

	if (duration <= 0) then
		player:Notify("Invalid duration.")

		return
	end

	if (#pieces > 0) then
		reason = string.Implode(" ", pieces)
	end

	for k, v in ipairs(targets) do
		v:SetPlayerData("MuteOOC", CurTime() + duration)
	end

	for k, v in ipairs(_player.GetAll()) do
		local time = "#for "..fl.lang:NiceTimeFull(v:GetNetVar("language"), duration)
		local phrase = L("OOCMuteMessage", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets)).." "..time..". ("..reason..")"

		v:Notify(phrase)
	end
end

COMMAND:Register()