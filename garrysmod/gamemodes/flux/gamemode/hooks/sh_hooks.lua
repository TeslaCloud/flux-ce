hook.Remove("PostDrawEffects", "RenderWidgets")
hook.Remove("PlayerTick", "TickWidgets")
hook.Remove("PlayerInitialSpawn", "PlayerAuthSpawn")
hook.Remove("RenderScene", "RenderStereoscopy")

-- Called when gamemode's server browser name needs to be retrieved.
function GM:GetGameDescription()
  local name_override = self.name_override
  return isstring(name_override) and name_override or "FL - "..fl.get_schema_name()
end

do
  local vectorAngle = FindMetaTable("Vector").Angle
  local normalizeAngle = math.NormalizeAngle

  function GM:CalcMainActivity(player, velocity)
    player:SetPoseParameter("move_yaw", normalizeAngle(vectorAngle(velocity)[2] - player:EyeAngles()[2]))
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
  local getWeaponHoldtype = fl.anim.GetWeaponHoldType

  -- Called when to translate player activities.
  function GM:TranslateActivity(player, act)
    local animations = player.flAnimTable

    if !animations then
      return self.BaseClass:TranslateActivity(player, act)
    end

    player.CalcSeqOverride = -1

    if player:InVehicle() then
      local vehicle = player:GetVehicle()
      local vehicleClass = vehicle:GetClass()
      local vehicleAnims = animations["vehicle"]

      if vehicleAnims and vehicleAnims[vehicleClass] then
        local anim = vehicleAnims[vehicleClass][1]
        local position = vehicleAnims[vehicleClass][2]

        if position then
          player:ManipulateBonePosition(0, position)
          player.shouldUndoBones = true
        end

        if isstring(anim) then
          player.CalcSeqOverride = player:LookupSequence(anim)

          -- Cache the result of LookupSequence for added performance.
          player.flAnimTable["vehicle"][vehicleClass][1] = player.CalcSeqOverride

          return
        end

        return anim
      else
        local anim = animations["normal"][ACT_MP_CROUCH_IDLE][1]

        if isstring(anim) then
          player.CalcSeqOverride = player:LookupSequence(anim)

          player.flAnimTable["normal"][ACT_MP_CROUCH_IDLE][1] = player.CalcSeqOverride

          return
        end

        return anim
      end
    elseif player:OnGround() then
      local holdType = getWeaponHoldtype(player, player:GetActiveWeapon())
      local holdTypeAnims = animations[holdType]

      if player.shouldUndoBones then
        player:ManipulateBonePosition(0, Vector(0, 0, 0))
        player.shouldUndoBones = false
      end

      if holdTypeAnims and holdTypeAnims[act] then
        local anim = holdTypeAnims[act]

        if istable(anim) then
          if hook.Call("ModelWeaponRaised", nil, player, model) then
            anim = anim[2]
          else
            anim = anim[1]
          end
        elseif isstring(anim) then
          player.CalcSeqOverride = player:LookupSequence(anim)

          player.flAnimTable[holdType][act] = player.CalcSeqOverride

          return
        end

        return anim
      end
    elseif animations["normal"]["glide"] then
      return animations["normal"]["glide"]
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
  local animCache = {}

  function GM:PlayerModelChanged(player, strNewModel, strOldModel)
    if !strNewModel then return end

    if CLIENT then
      player:SetIK(false)
    end

    if !animCache[strNewModel] then
      animCache[strNewModel] = fl.anim:GetTable(strNewModel)
    end

    player.flAnimTable = animCache[strNewModel]
  end
end

function GM:PlayerNoClip(player, bState)
  if bState == false then
    local bShouldExit = plugin.call("PlayerExitNoclip", player)

    if bShouldExit != nil then
      return bShouldExit
    end
  else
    local bShouldEnter = plugin.call("PlayerEnterNoclip", player)

    if bShouldEnter != nil then
      return bShouldEnter
    end
  end

  return true
end

function GM:PhysgunPickup(player, entity)
  if player:can("physgun_pickup") then
    return true
  end
end

concommand.Add("fl_save_pers", function()
  if fl.development and SERVER then
    hook.run("PersistenceSave")
  end
end)

function GM:OnReloaded()
  -- Reload the tools.
  local toolGun = weapons.GetStored("gmod_tool")

  for k, v in pairs(fl.tool:GetAll()) do
    toolGun.Tool[v.Mode] = v
  end

  if fl.development then
    for k, v in ipairs(_player.GetAll()) do
      self:PlayerModelChanged(v, v:GetModel(), v:GetModel())
    end
  end

  print("Auto-Reloaded")
end

-- Utility timers to call hooks that should be executed every once in a while.
timer.Create("OneMinute", 60, 0, function()
  hook.run("OneMinute")
end)

timer.Create("OneSecond", 1, 0, function()
  hook.run("OneSecond")
end)

timer.Create("HalfSecond", 0.5, 0, function()
  hook.run("HalfSecond")
end)

timer.Create("LazyTick", 0.125, 0, function()
  hook.run("LazyTick")
end)
