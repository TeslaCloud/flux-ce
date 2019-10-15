CMD.name = 'Respawn'
CMD.description = 'command.respawn.description'
CMD.syntax = 'command.respawn.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'respawn', 'plyrespawn' }

function CMD:on_run(player, targets, spawn_position)
  spawn_position = spawn_position and spawn_position:utf8lower()

  for k, v in ipairs(targets) do
    if v:Alive() then player:notify('error.respawn') return end

    local positions = { ['stay'] = v.last_pos, ['tp'] = player:GetEyeTraceNoCursor().HitPos }

    v:Spawn()
    v:teleport(positions[spawn_position] or positions['stay'])
    v:notify('notification.respawn', {
      player = player
    })
  end

  self:notify_staff('command.respawn.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })
end
