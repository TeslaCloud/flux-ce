--- The Respawn command respawns the targeted players, dead or alive, either where they are
-- (`stay`, the default) or at the spot the caller is looking at (`tp`). Allowed for
-- assistants by default.

CMD.name = 'Respawn'
CMD.description = 'command.respawn.description'
CMD.syntax = 'command.respawn.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'respawn', 'plyrespawn' }

--- Respawns the targeted players and notifies them and staff. A living target is respawned
-- in place: they keep their position and the direction they look in. A dead target comes
-- back at their last known position.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to respawn]
-- @param spawn_position='stay' [String 'stay' for where the target is (or was last seen, if
--   they are dead), 'tp' for the spot the caller is looking at; the server console can only
--   use 'stay']
function CMD:on_run(actor, targets, spawn_position)
  local look_pos = IsValid(actor) and actor:GetEyeTraceNoCursor().HitPos

  spawn_position = spawn_position and spawn_position:utf8lower()

  for k, v in ipairs(targets) do
    local alive = v:Alive()
    local angles = v:EyeAngles()
    local pos = alive and v:GetPos() or v.last_pos

    if spawn_position == 'tp' and look_pos then
      pos = look_pos
    end

    v:Spawn()

    if pos then
      v:teleport(pos)
    end

    if alive then
      v:SetEyeAngles(angles)
    end

    v:notify('notification.respawn', {
      player = IsValid(actor) and actor or get_player_name(actor)
    })
  end

  self:notify_staff('command.respawn.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
