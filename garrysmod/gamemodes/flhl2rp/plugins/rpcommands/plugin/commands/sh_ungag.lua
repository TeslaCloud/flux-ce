local COMMAND = Command("ungag")
COMMAND.name = "Ungag"
COMMAND.description = "Unmute player's OOC chats."
COMMAND.Syntax = "<name>"
COMMAND.category = "administration"
COMMAND.Arguments = 1
COMMAND.Immunity = true
COMMAND.Aliases = {"unmuteooc", "oocunmute", "plyungag"}

function COMMAND:OnRun(player, targets)
  for k, v in ipairs(targets) do
    v:SetPlayerData("MuteOOC", nil)
  end

  fl.player:NotifyAll(L("OOCUnmuteMessage", (IsValid(player) and player:name()) or "Console", util.PlayerListToString(targets)))
end

COMMAND:register()
