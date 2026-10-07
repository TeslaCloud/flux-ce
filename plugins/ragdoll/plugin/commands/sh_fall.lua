CMD.name = 'Fall'
CMD.description = 'command.fall.description'
CMD.syntax = 'command.fall.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'fallover', 'charfallover' }
CMD.no_console = true

--- Makes the player fall over and runs the getup command for them with the given delay.
-- Notifies the player instead if they are dead or already ragdolled.
-- @param actor [Player the caller]
-- @param delay=2 [String/Number seconds to pass to getup, clamped between 2 and 60]
function CMD:on_run(actor, delay)
  delay = math.clamp(tonumber(delay) or 0, 2, 60)

  if actor:Alive() and !actor:is_ragdolled() then
    actor:set_ragdoll_state(RAGDOLL_FALLENOVER)

    if delay and delay > 0 then
      actor:run_command('getup '..tostring(delay))
    end
  else
    actor:notify('error.cant_now')
  end
end
