local COMMAND = Command("static")
COMMAND.name = "Static"
COMMAND.description = "Makes the entity you're looking at static."
COMMAND.Syntax = "[none]"
COMMAND.category = "misc"
COMMAND.Aliases = {"staticadd", "staticpropadd"}

function COMMAND:OnRun(player)
  plugin.call("PlayerMakeStatic", player, true)
end

COMMAND:register()
