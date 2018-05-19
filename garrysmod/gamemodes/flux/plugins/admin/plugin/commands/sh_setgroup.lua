--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local COMMAND = Command("setgroup")
COMMAND.Name = "SetGroup"
COMMAND.Description = "#SetGroupCMD_Description"
COMMAND.Syntax = "#SetGroupCMD_Syntax"
COMMAND.Category = "player_management"
COMMAND.Arguments = 2
COMMAND.Immunity = true
COMMAND.Aliases = {"plysetgroup", "setusergroup", "plysetusergroup"}

function COMMAND:OnRun(player, targets, userGroup)
  if (fl.admin:GroupExists(userGroup)) then
    for k, v in ipairs(targets) do
      v:SetUserGroup(userGroup)
    end

    fl.player:NotifyAll(L("SetGroupCMD_Message", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), userGroup))
  else
    fl.player:Notify(player, L("Err_GroupNotValid", userGroup))
  end
end

COMMAND:Register()
