local COMMAND = Command.new("unban")
COMMAND.name = "Unban"
COMMAND.description = t"unbancmd.description"
COMMAND.syntax = t"unbancmd.syntax"
COMMAND.category = "administration"
COMMAND.arguments = 1
COMMAND.aliases = {"plyunban"}

function COMMAND:on_run(player, steam_id)
  if (isstring(steam_id) and steam_id != "") then
    local success, copy = fl.admin:remove_ban(steam_id)

    if (success) then
      fl.player:broadcast('unban_message', {
        admin = (IsValid(player) and player:Name()) or "Console",
        target = copy.name
      })
    else
      fl.player:notify(player, L("Err_NotBanned", steam_id))
    end
  end
end

COMMAND:register()
