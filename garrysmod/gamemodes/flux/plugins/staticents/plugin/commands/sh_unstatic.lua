local COMMAND = Command("unstatic")
COMMAND.name = "UnStatic"
COMMAND.description = "Makes the entity you're looking at not static."
COMMAND.Syntax = "[none]"
COMMAND.category = "misc"
COMMAND.Aliases = {"staticpropremove", "staticremove"}

function COMMAND:OnRun(player)
  plugin.call("PlayerMakeStatic", player, false)
end

COMMAND:register()
