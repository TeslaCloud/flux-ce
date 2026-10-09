--- Client side of the Spawn Points plugin: receives the spawn points from the server and
-- tells whether the local player is editing them.

--- Replaces the local list of spawn points and prepares the label and the color each point
-- is drawn with.
-- @param points [List<Map> points sent by the server, each with pos, ang and group]
function SpawnPoints:set_points(points)
  self.points = istable(points) and points or {}
  self.received = true

  for k, v in ipairs(self.points) do
    local group_label = self:get_group_label(v.group)

    v.label = t('ui.spawnpoints.label', { id = k, group = group_label })
    v.color = self:get_group_color(v.group)
  end
end

--- Checks whether the local player is holding the Spawn Point Tool and may use it, which is
-- when the spawn points are drawn.
-- @return [Boolean]
function SpawnPoints:is_tool_held()
  if !IsValid(PLAYER) or !PLAYER:Alive() then return false end

  local weapon = PLAYER:GetActiveWeapon()

  if !IsValid(weapon) or weapon:GetClass() != 'gmod_tool' or !isfunction(weapon.GetMode) then
    return false
  end

  return weapon:GetMode() == 'spawnpoint' and tobool(PLAYER:can('spawnpoints'))
end

Cable.receive('fl_spawnpoints_load', function(points)
  SpawnPoints:set_points(points)
end)
