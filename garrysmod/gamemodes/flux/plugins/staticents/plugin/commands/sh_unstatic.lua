local COMMAND = Command("unstatic")
COMMAND.Name = "UnStatic"
COMMAND.Description = "Makes the entity you're looking at not static."
COMMAND.Syntax = "[none]"
COMMAND.Category = "misc"
COMMAND.Aliases = {"staticpropremove", "staticremove"}

function COMMAND:OnRun(player)
  plugin.call("PlayerMakeStatic", player, false)
end

COMMAND:Register()
