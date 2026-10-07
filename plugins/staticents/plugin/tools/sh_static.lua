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

  local player = self:GetOwner()

  Plugin.call('PlayerMakeStatic', player, true)

  return true
end

--- Removes the static status of the entity the owner is looking at.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean always true]
function TOOL:RightClick(trace)
  if CLIENT then return true end

  local player = self:GetOwner()

  Plugin.call('PlayerMakeStatic', player, false)

  return true
end
