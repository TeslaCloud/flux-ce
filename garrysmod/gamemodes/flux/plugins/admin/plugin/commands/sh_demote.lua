local COMMAND = Command.new("demote")
COMMAND.name = "Demote"
COMMAND.description = t"demotecmd.description"
COMMAND.syntax = t"demotecmd.syntax"
COMMAND.category = "player_management"
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = {"plydemote"}

function COMMAND:on_run(player, targets)
  for k, target in ipairs(targets) do
    target:SetUserGroup("user")

    fl.player:NotifyAll(L("DemoteCMD_Message", (IsValid(player) and player:Name()) or "Console"), target:Name(), target:GetUserGroup())
  end
end

COMMAND:register()
