CMD.name = 'ForceGetUp'
CMD.description = 'command.forcegetup.description'
CMD.syntax = 'command.forcegetup.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.roleplay'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'forcegetup', 'plygetup' }

function CMD:on_run(player, targets, delay)
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
