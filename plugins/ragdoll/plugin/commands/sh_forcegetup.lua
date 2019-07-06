local COMMAND = Command.new('forcegetup')
COMMAND.name = 'ForceGetUp'
COMMAND.description = 'command.forcegetup.description'
COMMAND.syntax = 'command.forcegetup.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.roleplay'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'forcegetup', 'plygetup' }

function COMMAND:on_run(player, targets, delay)
  delay = math.clamp(tonumber(delay) or 0, 0, 60)

  for k, v in ipairs(targets) do
    if IsValid(v) and v:Alive() and v:is_ragdolled() then
      v:set_ragdoll_state(RAGDOLL_FALLENOVER)

      timer.simple(delay, function()
        if IsValid(v) and v:Alive() and v:is_ragdolled() then
          v:set_ragdoll_state(RAGDOLL_NONE)
        end
      end)
    end
  end

  self:notify_staff('command.forcegetup.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets),
    time = delay
  })
end

COMMAND:register()
