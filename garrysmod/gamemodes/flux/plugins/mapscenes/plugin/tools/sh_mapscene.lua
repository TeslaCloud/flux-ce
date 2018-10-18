TOOL.Category = 'Flux'
TOOL.Name = 'Mapscene tool'
TOOL.Command = nil
TOOL.ConfigName = ''

function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local player = self:GetOwner()

  if !IsValid(player) or !player:can('mapsceneadd') then return end

  flMapscene:add_point(player:EyePos(), player:GetAngles())

  fl.player:notify(player, '3d_text.text_added')

   return true
end
