COMMAND.name = 'Warn'
COMMAND.description = 'command.warn.description'
COMMAND.syntax = 'command.warn.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.player_management'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'plywarn', 'warn' }

function COMMAND:on_run(player, targets, ...)
  local reason = table.concat({ ... }, ' ')

  if !reason or reason == '' then
    player:notify('This is not a valid reason!')
  else
    self:notify_staff('command.warn.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets),
    reason = reason
   })

    for k, v in ipairs(targets) do
     v:notify( "notification.warn", { 
       reason = reason 
       })
    end
  end
end
