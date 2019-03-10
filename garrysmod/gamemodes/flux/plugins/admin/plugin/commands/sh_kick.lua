local COMMAND = Command.new('kick')
COMMAND.name = 'Kick'
COMMAND.description = t'kickcmd.description'
COMMAND.syntax = t'kickcmd.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.administration'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'plykick' }

function COMMAND:on_run(player, targets, ...)
  local pieces = {...}
  local reason = 'Kicked for unspecified reason.'

  if #pieces > 0 then
    reason = table.concat(pieces, ' ')
  end

  for k, v in ipairs(targets) do
    v:Kick(reason)
  end

  Flux.Player:broadcast('kick_message', { get_player_name(player), util.player_list_to_string(targets), reason })
end

COMMAND:register()
