--- Visible Legs lets players see the body of their character when they look down in first
-- person.
-- It draws a clientside copy of the local player's model that follows their animation, with
-- the head and the arms moved out of view. Nothing is drawn in observer mode, in third person
-- or while the player is dead.

PLUGIN:set_global('VisibleLegs')
PLUGIN:set_name('Visible Legs')
PLUGIN:set_author('NightAngel')
PLUGIN:set_description("Lets clients see their character's legs.")

if !CLIENT then return end

local hidden_bones = {
  'ValveBiped.Bip01_Head1',
  'ValveBiped.Bip01_Neck1',
  'ValveBiped.Bip01_Spine4',
  'ValveBiped.Bip01_L_Clavicle',
  'ValveBiped.Bip01_L_Hand',
  'ValveBiped.Bip01_L_Forearm',
  'ValveBiped.Bip01_L_Upperarm',
  'ValveBiped.Bip01_L_Finger0',
  'ValveBiped.Bip01_L_Finger01',
  'ValveBiped.Bip01_L_Finger02',
  'ValveBiped.Bip01_L_Finger1',
  'ValveBiped.Bip01_L_Finger11',
  'ValveBiped.Bip01_L_Finger12',
  'ValveBiped.Bip01_L_Finger2',
  'ValveBiped.Bip01_L_Finger21',
  'ValveBiped.Bip01_L_Finger22',
  'ValveBiped.Bip01_L_Finger3',
  'ValveBiped.Bip01_L_Finger31',
  'ValveBiped.Bip01_L_Finger32',
  'ValveBiped.Bip01_L_Finger4',
  'ValveBiped.Bip01_L_Finger41',
  'ValveBiped.Bip01_L_Finger42',
  'ValveBiped.Bip01_R_Clavicle',
  'ValveBiped.Bip01_R_Hand',
  'ValveBiped.Bip01_R_Forearm',
  'ValveBiped.Bip01_R_Upperarm',
  'ValveBiped.Bip01_R_Finger0',
  'ValveBiped.Bip01_R_Finger01',
  'ValveBiped.Bip01_R_Finger02',
  'ValveBiped.Bip01_R_Finger1',
  'ValveBiped.Bip01_R_Finger11',
  'ValveBiped.Bip01_R_Finger12',
  'ValveBiped.Bip01_R_Finger2',
  'ValveBiped.Bip01_R_Finger21',
  'ValveBiped.Bip01_R_Finger22',
  'ValveBiped.Bip01_R_Finger3',
  'ValveBiped.Bip01_R_Finger31',
  'ValveBiped.Bip01_R_Finger32',
  'ValveBiped.Bip01_R_Finger4',
  'ValveBiped.Bip01_R_Finger41',
  'ValveBiped.Bip01_R_Finger42'
}

-- For refresh.
if IsValid(PLAYER) and PLAYER.legs then
  PLAYER.legs:Remove()
end

--- Removes the local player's legs model whenever any player's model changes.
-- It is recreated with the current model the next time the legs are rendered.
-- @param target [Player the player whose model has changed]
-- @param new_model [String new model path]
-- @param old_model [String previous model path]
function VisibleLegs:PlayerModelChanged(target, new_model, old_model)
  if PLAYER.legs then
    PLAYER.legs:Remove()
  end
end

local offset = Vector(-50, -50, 0)
local scale = Vector(1, 1, 1)

--- Draws the local player's legs model in first person, following their animation.
-- Skipped while in observer mode, in third person, dead or looking above the horizon.
function VisibleLegs:RenderScreenspaceEffects()
  local client = PLAYER

  if !IsValid(client) or client:get_nv('observer') or client:ShouldDrawLocalPlayer() or !client:Alive() then return end

  local angs = client:EyeAngles()

  -- Because we don't need to draw the legs if you wouldn't even be able to see them.
  if angs.p < 0 then return end

  cam.Start3D(EyePos(), EyeAngles())
    if !IsValid(client.legs) then
      self:spawn_legs(client)
    end

    local real_time = RealTime()
    local legs = client.legs

    angs.p = 0
    angs.r = 0

    local rad_angle = math.rad(angs.y)
    local offset = -20
    local origin = client:GetPos()

    origin.x = origin.x + math.cos(rad_angle) * offset
    origin.y = origin.y + math.sin(rad_angle) * offset

    legs:SetPoseParameter('move_yaw', 360 * client:GetPoseParameter('move_yaw') - 180)
    legs:SetPoseParameter('move_x', client:GetPoseParameter('move_x') * 2 - 1)
    legs:SetPoseParameter('move_y', client:GetPoseParameter('move_y') * 2 - 1)

    legs:SetRenderMode(client:GetRenderMode())
    legs:SetMaterial(client:GetMaterial())
    legs:SetSequence(client:GetSequence())
    legs:SetColor(client:GetColor())
    legs:FrameAdvance(real_time - (legs.last_draw or real_time))
    legs:SetPlaybackRate(client:GetPlaybackRate())
    legs:SetRenderOrigin(origin)
    legs:SetRenderAngles(angs)
    legs:DrawModel()

    legs.last_draw = real_time
  cam.End3D()
end

--- Creates the clientside legs model of the player, replacing the previous one, and stores
-- it in client.legs. The upper body bones are moved out of view.
-- @param client [Player normally the local player]
function VisibleLegs:spawn_legs(client)
  if IsValid(client.legs) then
    client.legs:Remove()
  end

  client.legs = ClientsideModel(client:GetModel(), RENDERGROUP_VIEWMODEL)

  local legs = client.legs

  if IsValid(legs) then
    for i = 1, #hidden_bones do
      local bone = legs:LookupBone(hidden_bones[i])

      if bone then
        legs:ManipulateBonePosition(bone, offset)
        legs:ManipulateBoneScale(bone, scale)
      end
    end

    legs:SetNoDraw(true)
    legs:SetIK(true)
  end
end
