--- The Static Add/Remove tool: left click makes the entity the user is looking at static,
-- right click removes its static status.
-- The tool is tied to the 'static_tool' permission.

TOOL.Category = 'Flux'
TOOL.Name = 'Static Add/Remove'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'static_tool'

--- Makes the entity the owner is looking at static.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean always true]
function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  Plugin.call('PlayerMakeStatic', owner, true)

  return true
end

--- Removes the static status of the entity the owner is looking at.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean always true]
function TOOL:RightClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  Plugin.call('PlayerMakeStatic', owner, false)

  return true
end
