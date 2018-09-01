local COMMAND = Command.new("setgroup")
COMMAND.name = "SetGroup"
COMMAND.description = t"set_group.description"
COMMAND.syntax = t"set_group.syntax"
COMMAND.category = "player_management"
COMMAND.arguments = 2
COMMAND.immunity = true
COMMAND.aliases = {"plysetgroup", "setusergroup", "plysetusergroup"}

function COMMAND:on_run(player, targets, role)
  if (fl.admin:GroupExists(role)) then
    for k, v in ipairs(targets) do
      v:SetUserGroup(role)
    end

    fl.player:broadcast(L("SetGroupCMD_Message", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), role))
  else
    fl.player:notify(player, L("Err_GroupNotValid", role))
  end
end

COMMAND:register()
