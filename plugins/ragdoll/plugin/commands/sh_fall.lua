local COMMAND = Command.new('fall')
COMMAND.name = 'Fall'
COMMAND.description = 'command.fall.description'
COMMAND.syntax = 'command.fall.syntax'
COMMAND.category = 'permission.categories.roleplay'
COMMAND.aliases = { 'fallover', 'charfallover' }
COMMAND.no_console = true

function COMMAND:on_run(player, delay)
  delay = math.clamp(tonumber(delay) or 0, 2, 60)

  if player:Alive() and !player:is_ragdolled() then
    player:set_ragdoll_state(RAGDOLL_FALLENOVER)

    if delay and delay > 0 then
      player:run_command('getup '..tostring(delay))
    end
  else
    player:notify('error.cant_now')
  end
end

COMMAND:register()
