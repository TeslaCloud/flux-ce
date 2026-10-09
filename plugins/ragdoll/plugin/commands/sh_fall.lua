--- The `fall` command: the caller falls over into a ragdoll and gets back up once the delay
-- has passed.

CMD.name = 'Fall'
CMD.description = 'command.fall.description'
CMD.syntax = 'command.fall.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'fallover', 'charfallover' }
CMD.no_console = true

--- Makes the player fall over and get back up by themselves after the delay. Notifies the
-- player instead if they are dead, already ragdolled, in a vehicle or noclipping, or if they
-- have used the command less than the ragdoll_fall_cooldown config ago.
-- @param actor [Player the caller]
-- @param delay=nil [String/Number seconds until the player gets up, clamped between the
--   ragdoll_getup_time config and 60]
function CMD:on_run(actor, delay)
  if !actor:Alive() or actor:is_ragdolled() or actor:InVehicle() or actor:GetMoveType() == MOVETYPE_NOCLIP then
    actor:notify('error.cant_now')

    return
  end

  local cur_time = CurTime()
  local next_fall = actor.next_fall or 0

  if next_fall > cur_time then
    actor:notify('error.ragdoll.fall_cooldown', { time = math.ceil(next_fall - cur_time) })

    return
  end

  local minimum = Config.get('ragdoll_getup_time', 4)

  delay = math.clamp(tonumber(delay) or 0, minimum, math.max(minimum, 60))

  if actor:set_ragdoll_state(RAGDOLL_FALLENOVER, delay) then
    actor.next_fall = cur_time + Config.get('ragdoll_fall_cooldown', 5)
  else
    actor:notify('error.cant_now')
  end
end
