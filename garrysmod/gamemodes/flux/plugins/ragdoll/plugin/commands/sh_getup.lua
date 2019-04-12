local COMMAND = Command.new('getup')
COMMAND.name = 'GetUp'
COMMAND.description = 'getup.description'
COMMAND.syntax = 'getup.syntax'
COMMAND.category = 'categories.roleplay'
COMMAND.aliases = { 'chargetup', 'unfall', 'unfallover' }
COMMAND.no_console = true

function COMMAND:on_run(player, delay)
  delay = math.Clamp(tonumber(delay) or 4, 2, 60)

  if player:Alive() and player:is_ragdolled() then
    player:set_nv('getup_end', CurTime() + delay)
    player:set_nv('getup_time', delay)
    player:set_action('getup', true)

    timer.Simple(delay, function()
      player:set_ragdoll_state(RAGDOLL_NONE)

      player:reset_action()
    end)
  else
    player:notify(t'cant_now')
  end
end

COMMAND:register()
