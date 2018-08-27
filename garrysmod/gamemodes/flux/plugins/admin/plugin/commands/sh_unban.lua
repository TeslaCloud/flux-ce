local COMMAND = Command.new("unban")
COMMAND.name = "Unban"
COMMAND.description = "#UnbanCMD_Description"
COMMAND.syntax = "#UnbanCMD_Syntax"
COMMAND.category = "administration"
COMMAND.arguments = 1
COMMAND.aliases = {"plyunban"}

function COMMAND:on_run(player, steam_id)
  if (isstring(steam_id) and steam_id != "") then
    local success, copy = fl.admin:remove_ban(steam_id)

    if (success) then
      fl.player:NotifyAll(L("UnbanMessage", (IsValid(player) and player:Name()) or "Console", copy.name))
    else
      fl.player:Notify(player, L("Err_NotBanned", steam_id))
    end
  end
end

COMMAND:register()
