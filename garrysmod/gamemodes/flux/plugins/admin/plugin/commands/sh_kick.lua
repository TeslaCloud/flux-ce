--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local COMMAND = Command("kick")
COMMAND.Name = "Kick"
COMMAND.Description = "#KickCMD_Description"
COMMAND.Syntax = "#KickCMD_Syntax"
COMMAND.Category = "administration"
COMMAND.Arguments = 1
COMMAND.Immunity = true
COMMAND.Aliases = {"plykick"}

function COMMAND:OnRun(player, targets, ...)
  local pieces = {...}
  local reason = "Kicked for unspecified reason."

  if (#pieces > 0) then
    reason = string.Implode(" ", pieces)
  end

  for k, v in ipairs(targets) do
    v:Kick(reason)
  end

  fl.player:NotifyAll(L("KickMessage", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), reason))
end

COMMAND:Register()
