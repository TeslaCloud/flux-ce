hook.Remove('PostDrawEffects', 'RenderWidgets')
hook.Remove('PlayerTick', 'TickWidgets')
hook.Remove('PlayerInitialSpawn', 'PlayerAuthSpawn')
hook.Remove('RenderScene', 'RenderStereoscopy')

-- Called when gamemode's server browser name needs to be retrieved.
function GM:GetGameDescription()
  local name_override = self.name_override
  return isstring(name_override) and name_override or 'FL - '..fl.get_schema_name()
end

do
  local vectorAngle = FindMetaTable('Vector').Angle
  local normalizeAngle = math.NormalizeAngle

  function GM:CalcMainActivity(player, velocity)
    player:SetPoseParameter('move_yaw', normalizeAngle(vectorAngle(velocity)[2] - player:EyeAngles()[2]))
    player.CalcIdeal = ACT_MP_STAND_IDLE

    local base_class = self.BaseClass

    if (base_class:HandlePlayerNoClipping(player, velocity) or
      base_class:HandlePlayerDriving(player) or
      base_class:HandlePlayerVaulting(player, velocity) or
      base_class:HandlePlayerJumping(player, velocity) or
      base_class:HandlePlayerSwimming(player, velocity) or
      base_class:HandlePlayerDucking(player, velocity)) then
    else
      local len2D = velocity:Length2D()

      if len2D > 150 then
        player.CalcIdeal = ACT_MP_RUN
      elseif len2D > 0.5 then
        player.CalcIdeal = ACT_MP_WALK
      end
    end

    player.m_bWasOnGround = player:OnGround()
    player.m_bWasNoclipping = (player:GetMoveType() == MOVETYPE_NOCLIP and !player:InVehicle())

    return player.CalcIdeal, (player.CalcSeqOverride or -1)
  end
end

do
  local get_weapon_hold_type = fl.anim.GetWeaponHoldType

  -- Called when to translate player activities.
  function GM:TranslateActivity(player, act)
    local animations = player.fl_anim_table

    if !animations then
      return self.BaseClass:TranslateActivity(player, act)
    end

    player.CalcSeqOverride = -1

    if player:InVehicle() then
      local vehicle = player:GetVehicle()
      local vehicle_class = vehicle:GetClass()
      local vehicle_anims = animations['vehicle']

      if vehicle_anims and vehicle_anims[vehicle_class] then
        local anim = vehicle_anims[vehicle_class][1]
        local position = vehicle_anims[vehicle_class][2]

        if position then
          player:ManipulateBonePosition(0, position)
          player.should_undo_bones = true
        end

        if isstring(anim) then
          player.CalcSeqOverride = player:LookupSequence(anim)

          -- Cache the result of LookupSequence for added performance.
          player.fl_anim_table['vehicle'][vehicle_class][1] = player.CalcSeqOverride

          return
        end

        return anim
      else
        local anim = animations['normal'][ACT_MP_CROUCH_IDLE][1]

        if isstring(anim) then
          player.CalcSeqOverride = player:LookupSequence(anim)

          player.fl_anim_table['normal'][ACT_MP_CROUCH_IDLE][1] = player.CalcSeqOverride

          return
        end

        return anim
      end
    elseif player:OnGround() then
      local holdtype = get_weapon_hold_type(player, player:GetActiveWeapon())
      local holdtype_anims = animations[holdtype]

      if player.should_undo_bones then
        player:ManipulateBonePosition(0, Vector(0, 0, 0))
        player.should_undo_bones = false
      end

      if holdtype_anims and holdtype_anims[act] then
        local anim = holdtype_anims[act]

        if istable(anim) then
          if hook.Call('ModelWeaponRaised', nil, player, model) then
            anim = anim[2]
          else
            anim = anim[1]
          end
        elseif isstring(anim) then
          player.CalcSeqOverride = player:LookupSequence(anim)

          player.fl_anim_table[holdtype][act] = player.CalcSeqOverride

          return
        end

        return anim
      end
    elseif animations['normal']['glide'] then
      return animations['normal']['glide']
    end
  end
end

-- todo: proper weapon anims
function GM:DoAnimationEvent(player, event, data)
  if event == PLAYERANIMEVENT_ATTACK_PRIMARY then
    if player:Crouching() then
      player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_CROUCH_PRIMARYFIRE, true)
    else
      player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_STAND_PRIMARYFIRE, true)
    end

    return ACT_VM_PRIMARYATTACK
  elseif event == PLAYERANIMEVENT_ATTACK_SECONDARY then
    return ACT_VM_SECONDARYATTACK
  elseif event == PLAYERANIMEVENT_RELOAD then
    if player:Crouching() then
      player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_CROUCH, true)
    else
      player:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_STAND, true)
    end

    return ACT_INVALID
  elseif event == PLAYERANIMEVENT_JUMP then
    player.m_bJumping = true
    player.m_bFirstJumpFrame = true
    player.m_flJumpStartTime = CurTime()

    player:AnimRestartMainSequence()

    return ACT_INVALID
  elseif event == PLAYERANIMEVENT_CANCEL_RELOAD then
    player:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD)

    return ACT_INVALID
  end
end

do
  local anim_cache = {}

  function GM:PlayerModelChanged(player, new_model, old_model)
    if !new_model then return end

    if CLIENT then
      player:SetIK(false)
    end

    if !anim_cache[new_model] then
      anim_cache[new_model] = fl.anim:GetTable(new_model)
    end

    player.fl_anim_table = anim_cache[new_model]
  end
end

function GM:PlayerNoClip(player, b_state)
  if b_state == false then
    local b_should_exit = plugin.call('PlayerExitNoclip', player)

    if b_should_exit != nil then
      return b_should_exit
    end
  else
    local b_should_enter = plugin.call('PlayerEnterNoclip', player)

    if b_should_enter != nil then
      return b_should_enter
    end
  end

  return true
end

function GM:PhysgunPickup(player, entity)
  if player:can('physgun_pickup') then
    return true
  end
end

concommand.Add('fl_save_pers', function()
  if fl.development and SERVER then
    hook.run('PersistenceSave')
  end
end)

function GM:OnReloaded()
  -- Reload the tools.
  local tool_gun = weapons.GetStored('gmod_tool')

  for k, v in pairs(fl.tool:GetAll()) do
    tool_gun.Tool[v.Mode] = v
  end

  if fl.development then
    for k, v in ipairs(_player.GetAll()) do
      self:PlayerModelChanged(v, v:GetModel(), v:GetModel())
    end
  end

  print('Auto-Reloaded')
end

-- Utility timers to call hooks that should be executed every once in a while.
timer.Create('OneMinute', 60, 0, function()
  hook.run('OneMinute')
end)

timer.Create('OneSecond', 1, 0, function()
  hook.run('OneSecond')
end)

timer.Create('HalfSecond', 0.5, 0, function()
  hook.run('HalfSecond')
end)

timer.Create('LazyTick', 0.125, 0, function()
  hook.run('LazyTick')
end)
