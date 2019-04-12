local COMMAND = Command.new('forcefall')
COMMAND.name = 'ForceFall'
COMMAND.description = 'force_fall.description'
COMMAND.syntax = 'force_fall.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.roleplay'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'forcefallover', 'plyfall' }

function COMMAND:on_run(player, target, delay)
  if isnumber(delay) and delay > 0 then
    delay = math.Clamp(delay or 0, 2, 60)
  end

  target = target[1]

  if IsValid(target) and target:Alive() and !target:is_ragdolled() then
    target:set_ragdoll_state(RAGDOLL_FALLENOVER)

    player:notify(target:name()..' has been ragdolled!')

    if delay and delay > 0 then
      target:notify('Getting up...')

      timer.Simple(delay, function()
        target:set_ragdoll_state(RAGDOLL_NONE)
      end)
    end
  else
    player:notify(t'cant_now')
  end
end

COMMAND:register()
