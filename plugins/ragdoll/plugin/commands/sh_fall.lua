CMD.name = 'Fall'
CMD.description = 'command.fall.description'
CMD.syntax = 'command.fall.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'fallover', 'charfallover' }
CMD.no_console = true

function CMD:on_run(player, delay)
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
