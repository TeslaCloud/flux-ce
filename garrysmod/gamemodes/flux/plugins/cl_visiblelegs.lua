PLUGIN:set_global('flVisibleLegs')
PLUGIN:set_name('Visible Legs')
PLUGIN:set_author('NightAngel')
PLUGIN:set_description("Lets clients see their character's legs.")

if !CLIENT then return end

local hiddenBones = {
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
if IsValid(fl.client) and fl.client.legs then
  fl.client.legs:Remove()
end

function flVisibleLegs:PlayerModelChanged(player, sNewModel, sOldModel)
  if fl.client.legs then
    fl.client.legs:Remove()
  end
end

local offset = Vector(-50, -50, 0)
local scale = Vector(1, 1, 1)

function flVisibleLegs:SpawnLegs(player)
  if IsValid(player.legs) then
    player.legs:Remove()
  end

  player.legs = ClientsideModel(player:GetModel(), RENDERGROUP_VIEWMODEL)

  local legs = player.legs

  if IsValid(legs) then
    for k, v in pairs(hiddenBones) do
      local bone = legs:LookupBone(v)

      if bone then
        legs:ManipulateBonePosition(bone, offset)
        legs:ManipulateBoneScale(bone, scale)
      end
    end

    legs:SetNoDraw(true)
    legs:SetIK(true)
  end
end

function flVisibleLegs:RenderScreenspaceEffects()
  local player = fl.client

  if player:get_nv('observer') or player:ShouldDrawLocalPlayer() or !player:Alive() then return end

  local angs = player:EyeAngles()

  -- Because we don't need to draw the legs if you wouldn't even be able to see them.
  if angs.p < 0 then return end

  cam.Start3D(EyePos(), EyeAngles())
    if !IsValid(player.legs) then
      self:SpawnLegs(player)
    end

    local realTime = RealTime()
    local legs = player.legs

    angs.p = 0
    angs.r = 0

    local radAngle = math.rad(angs.y)
    local offset = -20
    local origin = player:GetPos()

    origin.x = origin.x + math.cos(radAngle) * offset
    origin.y = origin.y + math.sin(radAngle) * offset

    legs:SetPoseParameter('move_yaw', 360 * player:GetPoseParameter('move_yaw') - 180)
    legs:SetPoseParameter('move_x', player:GetPoseParameter('move_x') * 2 - 1)
    legs:SetPoseParameter('move_y', player:GetPoseParameter('move_y') * 2 - 1)

    legs:SetRenderMode(player:GetRenderMode())
    legs:SetMaterial(player:GetMaterial())
    legs:SetSequence(player:GetSequence())
    legs:SetColor(player:GetColor())
    legs:FrameAdvance(realTime - (legs.lastDraw or realTime))
    legs:SetPlaybackRate(player:GetPlaybackRate())
    legs:SetRenderOrigin(origin)
    legs:SetRenderAngles(angs)
    legs:DrawModel()

    legs.lastDraw = realTime
  cam.End3D()
end
