COMMAND.name = 'Respawn'
COMMAND.description = 'command.respawn.description'
COMMAND.syntax = 'command.respawn.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.player_management'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'respawn', 'plyrespawn' }

function COMMAND:on_run(player, targets, spawn_position)
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
