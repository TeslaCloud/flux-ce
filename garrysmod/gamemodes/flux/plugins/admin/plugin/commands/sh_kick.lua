local COMMAND = Command.new("kick")
COMMAND.name = "Kick"
COMMAND.description = t"kickcmd.description"
COMMAND.syntax = t"kickcmd.syntax"
COMMAND.category = "administration"
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = {"plykick"}

function COMMAND:on_run(player, targets, ...)
  local pieces = {...}
  local reason = "Kicked for unspecified reason."

  if (#pieces > 0) then
    reason = string.Implode(" ", pieces)
  end

  for k, v in ipairs(targets) do
    v:Kick(reason)
  end

  fl.player:NotifyAll(L("KickMessage", (IsValid(player) and player:Name()) or "Console", util.PlayerListToString(targets), reason))
end

COMMAND:register()
