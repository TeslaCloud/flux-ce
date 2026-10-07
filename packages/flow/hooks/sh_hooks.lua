--- Removes unused sandbox hooks and, on the server, imports the configuration from the
-- settings, loads the config, connects to the database and registers the Discord webhooks.
-- Runs the FLInitialize hook when done.
function GM:Initialize()
  hook.Remove('PostDrawEffects', 'RenderWidgets')
  hook.Remove('PlayerTick', 'TickWidgets')
  hook.Remove('PlayerInitialSpawn', 'PlayerAuthSpawn')
  hook.Remove('RenderScene', 'RenderStereoscopy')

  if SERVER then
    if !istable(Settings.server) then
      error 'Serverside settings missing! Check your YAML configuration files!\n'
    end

    local config_data = Settings.server.configuration
    local webhooks    = Settings.server.webhooks

    if istable(config_data) then
      Config.import(config_data, CONFIG_FLUX)
    end

    Config.load()

    ActiveRecord.establish_connection(ActiveRecord.db_settings)

    if istable(webhooks) then
      for id, data in pairs(webhooks) do
        if id != 'example' then
          if isstring(data.id) and isstring(data.key) then
            Webhook:add(id, Webhook.new(data.id, data.key, data.types))
          else
            ErrorNoHalt('Unable to add Discord webhook "'..tostring(id)..'" (invalid configuration)\n')
          end
        end
      end
    end
  end

  hook.Run('FLInitialize')
end

--- Returns the gamemode name shown in the server browser: name_override if it is a string,
-- otherwise 'FL - ' followed by the schema name.
-- @return [String]
function GM:GetGameDescription()
  local name_override = self.name_override
  return isstring(name_override) and name_override or 'FL - '..Flux.get_schema_name()
end

-- Disable default hooks for mouth move and grab ear.

--- Does nothing, which disables the default ear grab animation while chatting.
function GM:GrabEarAnimation()
end

--- Does nothing, which disables the default mouth movement while using voice chat.
function GM:MouthMoveAnimation()
end

do
  local vector_angle = FindMetaTable('Vector').Angle
  local normalize_angle = math.NormalizeAngle

  --- Picks the base activity of a player (idle, walking or running) and updates their
  -- move_yaw pose parameter. An animation forced with Player#set_animation takes priority.
  -- @param player [Player]
  -- @param velocity [Vector velocity of the player]
  -- @return [Number activity (ACT_ enum, or -1 for a forced animation), Number sequence to
  --   play instead of the activity, or -1 for none]
  function GM:CalcMainActivity(player, velocity)
    player:SetPoseParameter('move_yaw', normalize_angle(vector_angle(velocity)[2] - player:EyeAngles()[2]))
    player.CalcIdeal = ACT_MP_STAND_IDLE

    local animation = player.fl_animation

    if animation then
      return -1, animation
    end

    local base_class = self.BaseClass

    if !(base_class:HandlePlayerNoClipping(player, velocity) or
      base_class:HandlePlayerDriving(player) or
      base_class:HandlePlayerVaulting(player, velocity) or
      base_class:HandlePlayerJumping(player, velocity) or
      base_class:HandlePlayerSwimming(player, velocity) or
      base_class:HandlePlayerDucking(player, velocity)) then
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
  local get_weapon_hold_type = Flux.Anim.get_weapon_hold_type

  --- Translates an activity into the animation that the Flux animation tables define for the
  -- player's model, weapon hold type or vehicle. Models without an animation table are
  -- handled by the base gamemode.
  -- @param player [Player]
  -- @param act [Number activity to translate, ACT_ enum]
  -- @return [Number translated activity or sequence ID, or nil if the tables have no match]
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
          player.should_reset_position = true
        end

        if isstring(anim) then
          player.CalcSeqOverride = player:LookupSequence(anim)

          -- Cache the result of LookupSequence for added performance.
          player.fl_anim_table['vehicle'][vehicle_class][1] = player.CalcSeqOverride

          return player.CalcSeqOverride
        end

        return anim
      else
        return animations['normal'][ACT_MP_CROUCH_IDLE][1]
      end
    elseif player:OnGround() then
      local holdtype = get_weapon_hold_type(player, player:GetActiveWeapon())
      local holdtype_anims = animations[holdtype]

      if player.should_reset_position then
        player:ManipulateBonePosition(0, vector_origin)
        player.should_reset_position = nil
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

          return player.CalcSeqOverride
        end

        return anim
      end
    elseif animations['normal']['glide'] then
      return animations['normal']['glide']
    end
  end
end

-- todo: proper weapon anims

--- Plays the attack and reload gestures and handles the jump and reload cancel events.
-- @param player [Player]
-- @param event [Number animation event, PLAYERANIMEVENT_ enum]
-- @param data [Number data of the event; unused]
-- @return [Number activity for the view model or ACT_INVALID; nil for unhandled events]
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

  --- Assigns the animation table of the new model to the player and, on the client, disables
  -- inverse kinematics for them. Does nothing if no new model is given.
  -- @param player [Player]
  -- @param new_model [String path of the new model]
  -- @param old_model [String path of the previous model]
  function GM:PlayerModelChanged(player, new_model, old_model)
    if !new_model then return end

    if CLIENT then
      player:SetIK(false)
    end

    if !anim_cache[new_model] then
      anim_cache[new_model] = Flux.Anim:get_table(new_model)
    end

    player.fl_anim_table = anim_cache[new_model]
  end
end

--- Decides whether a player may toggle noclip by asking the plugins through the
-- PlayerEnterNoclip and PlayerExitNoclip hooks. Allowed if no plugin returns a value.
-- @param player [Player]
-- @param state [Boolean true when entering noclip, false when leaving it]
-- @return [Boolean whether the change is allowed]
function GM:PlayerNoClip(player, state)
  if state == false then
    local should_exit = Plugin.call('PlayerExitNoclip', player)

    if should_exit != nil then
      return should_exit
    end
  else
    local should_enter = Plugin.call('PlayerEnterNoclip', player)

    if should_enter != nil then
      return should_enter
    end
  end

  return true
end

--- Lets players with the physgun_pickup permission pick entities up with the physics gun.
-- @param player [Player]
-- @param entity [Entity the entity being picked up]
-- @return [Boolean true if the player has the permission, nil otherwise]
function GM:PhysgunPickup(player, entity)
  if player:can('physgun_pickup') then
    return true
  end
end

concommand.Add('fl_save_pers', function()
  if Flux.development and SERVER then
    hook.run('PersistenceSave')
  end
end)

--- After a Lua refresh, registers the Flux tools with the tool gun again and, in
-- development, reapplies the animation table of every player.
function GM:OnReloaded()
  -- Reload the tools.
  local toolgun = weapons.GetStored('gmod_tool')

  for k, v in pairs(Flux.Tool.stored) do
    toolgun.Tool[v.Mode] = v
  end

  if Flux.development then
    for k, v in ipairs(_player.all()) do
      self:PlayerModelChanged(v, v:GetModel(), v:GetModel())
    end
  end

  print('Auto-Reloaded')
end

-- Utility timers to call hooks that should be executed every once in a while.
timer.Create('fl_one_minute', 60, 0, function()
  hook.run('OneMinute')

  local i = 0

  for k, v in ipairs(_player.all()) do
    i = i + 1

    timer.Simple(0.25 * i, function()
      if IsValid(v) then
        hook.run('PlayerOneMinute', v)
      end
    end)
  end
end)

timer.Create('fl_one_second', 1, 0, function()
  hook.run('OneSecond')
end)

timer.Create('fl_half_second', 0.5, 0, function()
  hook.run('HalfSecond')
end)

timer.Create('fl_lazy_tick', 0.125, 0, function()
  hook.run('LazyTick')
end)
