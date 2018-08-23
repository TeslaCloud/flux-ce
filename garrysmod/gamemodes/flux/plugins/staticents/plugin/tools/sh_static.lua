TOOL.category = "Flux"
TOOL.name = "Static Add/Remove"
TOOL.Command = nil
TOOL.ConfigName = ""

function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local player = self:GetOwner()

  plugin.call("PlayerMakeStatic", player, true)

   return true
end

function TOOL:RightClick(trace)
  if CLIENT then return true end

  local player = self:GetOwner()

  plugin.call("PlayerMakeStatic", player, false)

  return true
end
