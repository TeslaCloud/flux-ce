local COMMAND = Command("static")
COMMAND.Name = "Static"
COMMAND.Description = "Makes the entity you're looking at static."
COMMAND.Syntax = "[none]"
COMMAND.Category = "misc"
COMMAND.Aliases = {"staticadd", "staticpropadd"}

function COMMAND:OnRun(player)
  plugin.call("PlayerMakeStatic", player, true)
end

COMMAND:Register()
