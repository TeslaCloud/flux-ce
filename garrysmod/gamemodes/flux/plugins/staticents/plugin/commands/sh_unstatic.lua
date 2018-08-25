local COMMAND = Command.new("unstatic")
COMMAND.name = "UnStatic"
COMMAND.description = "Makes the entity you're looking at not static."
COMMAND.syntax = "[none]"
COMMAND.category = "misc"
COMMAND.aliases = {"staticpropremove", "staticremove"}

function COMMAND:OnRun(player)
  plugin.call("PlayerMakeStatic", player, false)
end

COMMAND:register()
