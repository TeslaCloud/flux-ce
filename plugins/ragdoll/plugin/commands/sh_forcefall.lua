COMMAND.name = 'ForceFall'
COMMAND.description = 'command.forcefall.description'
COMMAND.syntax = 'command.forcefall.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.roleplay'
COMMAND.arguments = 1
COMMAND.player_arg = 1
COMMAND.aliases = { 'forcefallover', 'plyfall' }

function COMMAND:on_run(player, targets, delay)
  delay = math.clamp(tonumber(delay) or 0, 0, 60)

  for k, v in ipairs(targets) do
    if IsValid(v) and v:Alive() and !v:is_ragdolled() then
      v:set_ragdoll_state(RAGDOLL_FALLENOVER)

      if delay > 0 then
        v:run_command('getup '..tostring(delay))
      end
    end
  end

  self:notify_staff('command.forcefall.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets),
    time = delay
  })
end
