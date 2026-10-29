--- The Static Add/Remove tool: left click makes the entity the user is looking at static,
-- right click removes its static status.
-- The tool is tied to the 'static_tool' permission.

TOOL.Category = 'Flux'
TOOL.Name = 'Static Add/Remove'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'static_tool'

--- Makes the entity the owner is looking at static.
-- @param _trace [Map trace result of the tool owner's aim]
-- @return [Boolean always true]
function TOOL:LeftClick(_trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  Plugin.call('PlayerSetEntityStatic', owner, true)

  return true
end

--- Removes the static status of the entity the owner is looking at.
-- @param _trace [Map trace result of the tool owner's aim]
-- @return [Boolean always true]
function TOOL:RightClick(_trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  Plugin.call('PlayerSetEntityStatic', owner, false)

  return true
end
