CMD.name = 'Respawn'
CMD.description = 'command.respawn.description'
CMD.syntax = 'command.respawn.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'respawn', 'plyrespawn' }

--- Respawns the targeted dead players and notifies them and staff. Stops with an error
-- notification at the first target that is still alive.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to respawn]
-- @param spawn_position='stay' [String 'stay' for the target's last known position, 'tp' for
--   the spot the caller is looking at]
function CMD:on_run(actor, targets, spawn_position)
  spawn_position = spawn_position and spawn_position:utf8lower()

  for k, v in ipairs(targets) do
    if v:Alive() then actor:notify('error.respawn') return end

    local positions = { ['stay'] = v.last_pos, ['tp'] = actor:GetEyeTraceNoCursor().HitPos }

    v:Spawn()
    v:teleport(positions[spawn_position] or positions['stay'])
    v:notify('notification.respawn', {
      player = actor
    })
  end

  self:notify_staff('command.respawn.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
