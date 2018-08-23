local COMMAND = Command("unban")
COMMAND.name = "Unban"
COMMAND.description = "#UnbanCMD_Description"
COMMAND.Syntax = "#UnbanCMD_Syntax"
COMMAND.category = "administration"
COMMAND.Arguments = 1
COMMAND.Aliases = {"plyunban"}

function COMMAND:OnRun(player, steamID)
  if (isstring(steamID) and steamID != "") then
    local success, copy = fl.admin:RemoveBan(steamID)

    if (success) then
      fl.player:NotifyAll(L("UnbanMessage", (IsValid(player) and player:name()) or "Console", copy.name))
    else
      fl.player:Notify(player, L("Err_NotBanned", steamID))
    end
  end
end

COMMAND:register()
