local COMMAND = Command.new('fall')
COMMAND.name = 'Fall'
COMMAND.description = 'command.fall.description'
COMMAND.syntax = 'command.fall.syntax'
COMMAND.category = 'perm.categories.roleplay'
COMMAND.aliases = { 'fallover', 'charfallover' }
COMMAND.no_console = true

function COMMAND:on_run(player, delay)
  delay = tonumber(delay)

  if isnumber(delay) and delay > 0 then
    delay = math.Clamp(delay or 0, 2, 60)
  end

  if player:Alive() and !player:is_ragdolled() then
    player:set_ragdoll_state(RAGDOLL_FALLENOVER)

    if delay and delay > 0 then
      player:run_command('getup '..tostring(delay))
    end
  else
    player:notify(t'error.cant_now')
  end
end

COMMAND:register()
