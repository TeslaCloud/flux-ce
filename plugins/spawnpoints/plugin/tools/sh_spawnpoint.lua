--- The Spawn Point Tool places and removes spawn points. Left click adds a point where the
-- owner stands, facing the way they look, for the group picked in the tool's settings:
-- everyone, a faction or a class. Right click removes the point the owner is aiming at.
-- While the tool is held the existing points are drawn in the world. The tool requires the
-- 'spawnpoints' permission, which each of its actions checks as well.

TOOL.Category = 'Flux'
TOOL.Name = 'Spawn Point Tool'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'spawnpoints'

TOOL.ClientConVar['group'] = 'default'

local aim_tolerance = 16
local nearest_radius = 48

--- Adds a spawn point for the selected group at the spot the owner stands on, or the spot on
-- the ground below them when they are in the air.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if the point was added (always true clientside), false if the
--   selected group does not exist or there is no room for a point, nil if the owner is not
--   valid or lacks the 'spawnpoints' permission]
function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  if !IsValid(owner) or !owner:can('spawnpoints') then return end

  local group = self:GetClientInfo('group')

  if !SpawnPoints:is_valid_group(group) then
    owner:notify('error.spawnpoints.invalid_group')

    return false
  end

  local pos = SpawnPoints:get_floor_position(owner)

  if !pos then
    owner:notify('error.spawnpoints.no_room')

    return false
  end

  SpawnPoints:add_point(pos, owner:EyeAngles(), group)

  owner:notify('notification.spawnpoints.added', { group = SpawnPoints:get_group_name(group) })

  return true
end

--- Removes the spawn point the owner is aiming at: the one their line of sight runs through
-- first, or else the one closest to the spot they are looking at, or else the one they are
-- standing on.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if a point was removed (always true clientside), false if the owner
--   is not aiming at a point, nil if the owner is not valid or lacks the 'spawnpoints'
--   permission]
function TOOL:RightClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  if !IsValid(owner) or !owner:can('spawnpoints') then return end

  local shoot_pos = owner:GetShootPos()
  local index = SpawnPoints:find_aimed_point(
    shoot_pos,
    owner:GetAimVector(),
    shoot_pos:Distance(trace.HitPos) + aim_tolerance
  )

  if !index then
    index = SpawnPoints:find_nearest_point(trace.HitPos, nearest_radius)
      or SpawnPoints:find_nearest_point(owner:GetPos(), nearest_radius)
  end

  local point = index and SpawnPoints:remove_point(index)

  if !point then
    owner:notify('error.spawnpoints.none_aimed')

    return false
  end

  owner:notify('notification.spawnpoints.removed', { group = SpawnPoints:get_group_name(point.group) })

  return true
end

if CLIENT then
  --- Builds the tool's settings panel: a list of the groups a spawn point can be placed for.
  -- @param panel [Panel the tool's control panel]
  function TOOL.BuildCPanel(panel)
    panel:AddControl('Header', { Description = t'tool.spawnpoint.desc' })

    local combo_box = panel:ComboBox(t'tool.spawnpoint.group', 'spawnpoint_group')

    combo_box:SetSortItems(false)

    for k, v in ipairs(SpawnPoints:get_groups()) do
      combo_box:AddChoice(SpawnPoints:get_group_label(v), v)
    end
  end
end
