--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]local COMMAND = Command("unban")
COMMAND.Name = "Unban"
COMMAND.Description = "#UnbanCMD_Description"
COMMAND.Syntax = "#UnbanCMD_Syntax"
COMMAND.Category = "administration"
COMMAND.Arguments = 1
COMMAND.Aliases = {"plyunban"}

function COMMAND:OnRun(player, steamID)
  if (isstring(steamID) and steamID != "") then
    local success, copy = fl.admin:RemoveBan(steamID)

    if (success) then
      fl.player:NotifyAll(L("UnbanMessage", (IsValid(player) and player:Name()) or "Console", copy.name))
    else
      fl.player:Notify(player, L("Err_NotBanned", steamID))
    end
  end
end

COMMAND:Register()
