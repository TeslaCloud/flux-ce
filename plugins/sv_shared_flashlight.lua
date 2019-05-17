PLUGIN:set_name 'Shared Flashlight'
PLUGIN:set_author 'TeslaCloud Studios'
PLUGIN:set_description "Makes other player's flashlight lights visible to you."

-- experimental for now
if !Settings.experimental then return end

local flashlight_cutoff = 780 ^ 2
local light_mat = Material("effects/flashlight001")

function PLUGIN:PlayerSwitchedFlashlight(player)
  local on = !player.shared_flashlight_on

  if !on then
    if !IsValid(player.shared_flashlight) then return end

    player.shared_flashlight:Remove()
    player.shared_flashlight = nil 
  else
    player.shared_flashlight = ents.Create 'env_projectedtexture'
    player.shared_flashlight:SetParent(player)

    player.shared_flashlight:SetLocalPos(player:GetCurrentViewOffset())
    player.shared_flashlight:SetLocalAngles(Angle(0, 0, 0))

    player.shared_flashlight:SetKeyValue('enableshadows', 1)
    player.shared_flashlight:SetKeyValue('nearz', 12)
    player.shared_flashlight:SetKeyValue('lightfov', 35)
    player.shared_flashlight:SetKeyValue('farz', 1024)
    player.shared_flashlight:SetKeyValue('lightcolor', '255 255 255 255')

    player.shared_flashlight:Spawn()

    player.shared_flashlight:Input('SpotlightTexture', NULL, NULL, light_mat:GetString('$basetexture'))
  end

  player.shared_flashlight_on = on

  return false
end
