CMD.name = 'Fall'
CMD.description = 'command.fall.description'
CMD.syntax = 'command.fall.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'fallover', 'charfallover' }
CMD.no_console = true

--- Makes the player fall over and runs the getup command for them with the given delay.
-- Notifies the player instead if they are dead or already ragdolled.
-- @param player [Player the caller]
-- @param delay=2 [String/Number seconds to pass to getup, clamped between 2 and 60]
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
