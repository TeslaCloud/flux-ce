local COMMAND = Command.new('forcegetup')
COMMAND.name = 'ForceGetUp'
COMMAND.description = 'force_getup.description'
COMMAND.syntax = 'force_getup.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.roleplay'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'forcegetup', 'plygetup' }

function COMMAND:on_run(player, target, delay)
  delay = math.Clamp(delay or 0, 0, 60)
  target = target[1]

  if IsValid(target) and target:Alive() and target:is_ragdolled() then
    target:set_ragdoll_state(RAGDOLL_FALLENOVER)

    player:notify(target:name()..' has been unragdolled!')

    timer.Simple(delay, function()
      target:set_ragdoll_state(RAGDOLL_NONE)
    end)
  else
    player:notify(t'cant_now')
  end
end

COMMAND:register()
