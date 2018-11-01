local COMMAND = Command.new('getup')
COMMAND.name = 'GetUp'
COMMAND.description = t'getup.description'
COMMAND.syntax = t'getup.syntax'
COMMAND.category = 'roleplay'
COMMAND.aliases = { 'chargetup', 'unfall', 'unfallover' }
COMMAND.no_console = true

function COMMAND:on_run(player, delay)
  delay = math.Clamp(tonumber(delay) or 4, 2, 60)

  if player:Alive() and player:IsRagdolled() then
    player:set_nv('getup_end', CurTime() + delay)
    player:set_nv('getup_time', delay)
    player:set_action('getup', true)

    timer.Simple(delay, function()
      player:SetRagdollState(RAGDOLL_NONE)

      player:reset_action()
    end)
  else
    player:notify(t'cant_now')
  end
end

COMMAND:register()
