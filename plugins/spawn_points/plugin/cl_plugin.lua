--- Client side of the Spawn Points plugin: stores the spawn points that the server sends and
-- tells whether the local player is editing them.

--- Replaces the local list of spawn points and prepares the label and the color each point
-- is drawn with.
-- @param points [List<Map> points sent by the server, each with pos, ang and group]
function SpawnPoints:set_points(points)
  self.points = istable(points) and points or {}
  self.received = true

  for index, point in ipairs(self.points) do
    local group_label = self:get_group_label(point.group)

    point.label = t('ui.spawn_points.label', { id = index, group = group_label })
    point.color = self:get_group_color(point.group)
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

  return weapon:GetMode() == 'spawnpoint' and tobool(PLAYER:can('manage_spawn_points'))
end
