PLUGIN:set_name 'Shared Flashlight'
PLUGIN:set_author 'TeslaCloud Studios'
PLUGIN:set_description "Makes other players' flashlight lights visible to you."

-- experimental for now
if !Settings.experimental then return end

local flashlight_cutoff = 780 ^ 2
local light_mat = Material('effects/flashlight001')

--- Toggles a projected texture attached to the player, so that other players can see the
-- light of their flashlight.
-- @param actor [Player]
-- @return [Boolean false; nil if the light was on but its entity is no longer valid]
function PLUGIN:PlayerSwitchedFlashlight(actor)
  local on = !actor.shared_flashlight_on

  if !on then
    if !IsValid(actor.shared_flashlight) then return end

    actor.shared_flashlight:Remove()
    actor.shared_flashlight = nil
  else
    actor.shared_flashlight = ents.Create 'env_projectedtexture'
    actor.shared_flashlight:SetParent(actor)

    actor.shared_flashlight:SetLocalPos(actor:GetCurrentViewOffset())
    actor.shared_flashlight:SetLocalAngles(Angle(0, 0, 0))

    actor.shared_flashlight:SetKeyValue('enableshadows', 1)
    actor.shared_flashlight:SetKeyValue('nearz', 12)
    actor.shared_flashlight:SetKeyValue('lightfov', 35)
    actor.shared_flashlight:SetKeyValue('farz', 1024)
    actor.shared_flashlight:SetKeyValue('lightcolor', '255 255 255 255')

    actor.shared_flashlight:Spawn()

    actor.shared_flashlight:Input('SpotlightTexture', NULL, NULL, light_mat:GetString('$basetexture'))
  end

  actor.shared_flashlight_on = on

  return false
end
