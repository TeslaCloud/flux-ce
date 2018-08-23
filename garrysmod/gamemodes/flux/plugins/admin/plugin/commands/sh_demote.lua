local COMMAND = Command("demote")
COMMAND.name = "Demote"
COMMAND.description = "#DemoteCMD_Description"
COMMAND.Syntax = "#DemoteCMD_Syntax"
COMMAND.category = "player_management"
COMMAND.Arguments = 1
COMMAND.Immunity = true
COMMAND.Aliases = {"plydemote"}

function COMMAND:OnRun(player, targets)
  for k, target in ipairs(targets) do
    target:SetUserGroup("user")

    fl.player:NotifyAll(L("DemoteCMD_Message", (IsValid(player) and player:Name()) or "Console"), target:Name(), target:GetUserGroup())
  end
end

COMMAND:register()
