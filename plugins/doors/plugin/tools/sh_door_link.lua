--- The Door Link tool links doors into groups that are owned, shared and labeled together.
-- The first left click picks the main door of a group, every left click after that links
-- the door the user is looking at to it. Right click takes a door out of its group, or
-- breaks the group up if the door is its main door, and reload forgets the picked door.
-- The tool is tied to the 'manage_doors' permission.

local IsValid = IsValid

TOOL.Category = 'Flux'
TOOL.Name = 'Door Link'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'manage_doors'

--- Picks the door the owner is looking at as the main door of a group, or links it to the
-- door that has been picked before.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true on the client and when a door was picked or linked, false otherwise]
function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()
  local entity = trace.Entity

  if !owner:can('manage_doors') then return false end

  if !IsValid(entity) or !entity:is_door() then
    owner:notify('error.door.not_a_door')

    return false
  end

  local parent = owner.door_link_parent

  if !IsValid(parent) then
    owner.door_link_parent = Doors:get_root(entity)

    owner:notify('notification.door.link_picked')

    return true
  end

  local success, reason = Doors:link(entity, parent)

  if !success then
    owner:notify(reason)

    return false
  end

  owner:notify('notification.door.linked', { count = #Doors:get_group(parent) })

  return true
end

--- Takes the door the owner is looking at out of its group, or breaks the group up if the
-- door is its main door.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true on the client and when a door was unlinked, false otherwise]
function TOOL:RightClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()
  local entity = trace.Entity

  if !owner:can('manage_doors') then return false end

  if !IsValid(entity) or !entity:is_door() then
    owner:notify('error.door.not_a_door')

    return false
  end

  local success, reason = Doors:unlink(entity)

  if !success then
    owner:notify(reason)

    return false
  end

  owner:notify('notification.door.unlinked')

  return true
end

--- Forgets the door that was picked as the main door of a group.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true on the client and when a picked door was forgotten, false otherwise]
function TOOL:Reload(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  if !IsValid(owner.door_link_parent) then return false end

  owner.door_link_parent = nil

  owner:notify('notification.door.link_cleared')

  return true
end
