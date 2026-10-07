CMD.name = 'GetUp'
CMD.description = 'command.getup.description'
CMD.syntax = 'command.getup.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'chargetup', 'unfall', 'unfallover' }
CMD.no_console = true

--- Makes the ragdolled player get up after the delay, showing them a progress bar until
-- then. Notifies the player instead if they are dead or not ragdolled.
-- @param actor [Player the caller]
-- @param delay=4 [String/Number seconds it takes to get up, clamped between 4 and 60]
function CMD:on_run(actor, delay)
  delay = math.clamp(tonumber(delay) or 0, 4, 60)

  if actor:Alive() and actor:is_ragdolled() then
    actor:set_nv('getup_end', CurTime() + delay)
    actor:set_nv('getup_time', delay)
    actor:set_action('getup', true)

    timer.Simple(delay, function()
      if IsValid(actor) and actor:Alive() and actor:is_ragdolled() then
        actor:set_ragdoll_state(RAGDOLL_NONE)

        actor:reset_action()
      end
    end)
  else
    actor:notify('error.cant_now')
  end
end
