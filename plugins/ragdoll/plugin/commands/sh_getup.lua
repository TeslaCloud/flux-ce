CMD.name = 'GetUp'
CMD.description = 'command.getup.description'
CMD.syntax = 'command.getup.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'chargetup', 'unfall', 'unfallover' }
CMD.no_console = true

--- Makes the ragdolled player get up after the delay, showing them a progress bar until
-- then. Notifies the player instead if they are dead or not ragdolled.
-- @param player [Player the caller]
-- @param delay=4 [String/Number seconds it takes to get up, clamped between 4 and 60]
function CMD:on_run(player, delay)
  delay = math.clamp(tonumber(delay) or 0, 4, 60)

  if player:Alive() and player:is_ragdolled() then
    player:set_nv('getup_end', CurTime() + delay)
    player:set_nv('getup_time', delay)
    player:set_action('getup', true)

    timer.simple(delay, function()
      if IsValid(player) and player:Alive() and player:is_ragdolled() then
        player:set_ragdoll_state(RAGDOLL_NONE)

        player:reset_action()
      end
    end)
  else
    player:notify('error.cant_now')
  end
end
