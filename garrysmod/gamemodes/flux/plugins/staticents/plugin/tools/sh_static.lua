TOOL.Category = 'Flux'
TOOL.Name = 'Static Add/Remove'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'static_tool'

function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local player = self:GetOwner()

  Plugin.call('PlayerMakeStatic', player, true)

  return true
end

function TOOL:RightClick(trace)
  if CLIENT then return true end

  local player = self:GetOwner()

  Plugin.call('PlayerMakeStatic', player, false)

  return true
end
