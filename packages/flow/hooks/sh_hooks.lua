--- The Flux gamemode table: the handlers of GMod's gamemode hooks that turn Flux into a
-- gamemode derived from sandbox.
-- The handlers set players up when they join and spawn, check sandbox actions such as
-- spawning props against the Flux permissions, play the animations defined by the
-- `Flux.Anim` tables, draw the HUD and save the data. While doing so they run Flux's own
-- hooks (`PlayerInitialized`, `PostPlayerSpawn`, `PlayerThink`, `LazyTick`, `FLHUDPaint`
-- and so on, listed on the Hooks page), which are what plugins and schemas are meant to
-- implement instead of overriding the `GM` functions.
--
-- Plugin and schema handlers of a hook are called before the handlers added with
-- `hook.Add` and before the `GM` handler. The first handler that returns a non-nil value
-- ends the call, so the remaining handlers, including the gamemode's, do not run: only
-- return a value from a handler when the hook's documentation gives it a meaning. Hooks
-- that are run with `Plugin.call` never reach the `GM` handlers.
--
-- The handlers are split by realm. The shared ones cover initialization, player animations,
-- the noclip and physics gun checks and the timers behind the periodic hooks (`LazyTick`,
-- `HalfSecond`, `OneSecond`, `OneMinute`); the server and the client ones are in the `sv_`
-- and `cl_` hook files.

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

  --- Called at the end of the gamemode's `Initialize` handler, on both realms.
  -- On the server the config has been loaded, the connection to the database has been
  -- started and the Discord webhooks from the settings have been registered by then.
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
  local get_weapon_hold_type = Flux.Anim.get_weapon_hold_type
  local ACT_MP_STAND_IDLE = ACT_MP_STAND_IDLE
  local walk_speed_sqr = 0.5 * 0.5

  --- Returns the compiled animations for the hold type of a weapon. Hold types that the
  -- animation table does not define use the 'normal' hold type.
  -- @param actor [Player]
  -- @param animations [Map compiled animation table of the player's model]
  -- @param weapon=nil [Weapon weapon to take the hold type from, the active weapon if nil]
  -- @return [Map animations by key]
  local function hold_type_animations(actor, animations, weapon)
    local hold_type = get_weapon_hold_type(actor, weapon or actor:GetActiveWeapon())

    return animations[hold_type] or animations.normal
  end

  --- Turns an animation table entry into something the engine can play, looking sequence
  -- names up on the player's model and caching the IDs in the animation table.
  -- @param actor [Player]
  -- @param animations [Map compiled animation table of the player's model]
  -- @param anim [Number activity or String sequence name]
  -- @return [Number activity or sequence ID, Boolean true if it is a sequence ID]
  local function resolve(actor, animations, anim)
    if isstring(anim) then
      local sequence_ids = animations.sequence_ids
      local sequence = sequence_ids[anim]

      if !sequence then
        sequence = actor:LookupSequence(anim)
        sequence_ids[anim] = sequence
      end

      return sequence, true
    end

    return anim, false
  end

  --- Plays an animation table entry as a gesture that stops once it has finished.
  -- @param actor [Player]
  -- @param animations [Map compiled animation table of the player's model]
  -- @param slot [Number gesture slot, GESTURE_SLOT_ enum]
  -- @param anim [Number activity or String sequence name]
  local function restart_gesture(actor, animations, slot, anim)
    local is_sequence
    anim, is_sequence = resolve(actor, animations, anim)

    if is_sequence then
      if anim != -1 then
        actor:AddVCDSequenceToGestureSlot(slot, anim, 0, true)
      end
    else
      actor:AnimRestartGesture(slot, anim, true)
    end
  end

  --- Picks the base activity of a player (idle, walking or running), updates their
  -- move_yaw pose parameter and plays the landing gesture when they touch the ground.
  -- An animation forced with Player#set_animation takes priority. The run threshold comes
  -- from the animation table and has a small hysteresis so that the animation does not
  -- flicker when moving at about that speed.
  -- @param actor [Player]
  -- @param velocity [Vector velocity of the player]
  -- @return [Number activity (ACT_ enum, or -1 for a forced animation), Number sequence to
  --   play instead of the activity, or -1 for none]
  function GM:CalcMainActivity(actor, velocity)
    actor:SetPoseParameter('move_yaw', normalize_angle(vector_angle(velocity)[2] - actor:EyeAngles()[2]))
    actor.CalcIdeal = ACT_MP_STAND_IDLE

    local animation = actor.fl_animation

    if animation then
      return -1, animation
    end

    local base_class = self.BaseClass
    local animations = actor.fl_anim_table
    local on_ground = actor:OnGround()
    local is_noclipping = actor:GetMoveType() == MOVETYPE_NOCLIP

    if on_ground and actor.m_bWasOnGround == false and !is_noclipping then
      if animations then
        local land = hold_type_animations(actor, animations).land

        if land then
          restart_gesture(actor, animations, GESTURE_SLOT_JUMP, land)
        end
      else
        actor:AnimRestartGesture(GESTURE_SLOT_JUMP, ACT_LAND, true)
      end
    end

    if !(base_class:HandlePlayerNoClipping(actor, velocity) or
      base_class:HandlePlayerDriving(actor) or
      base_class:HandlePlayerVaulting(actor, velocity) or
      base_class:HandlePlayerJumping(actor, velocity) or
      base_class:HandlePlayerSwimming(actor, velocity) or
      base_class:HandlePlayerDucking(actor, velocity)) then
      local len_2d_sqr = velocity:Length2DSqr()
      local run_speed = animations and animations.run_speed or 150
      local keep_running_speed = run_speed * 0.85

      if len_2d_sqr > run_speed * run_speed
      or (actor.fl_running and len_2d_sqr > keep_running_speed * keep_running_speed) then
        actor.CalcIdeal = ACT_MP_RUN
        actor.fl_running = true
      else
        actor.fl_running = nil

        if len_2d_sqr > walk_speed_sqr then
          actor.CalcIdeal = ACT_MP_WALK
        end
      end
    end

    actor.m_bWasOnGround = on_ground
    actor.m_bWasNoclipping = (is_noclipping and !actor:InVehicle())

    return actor.CalcIdeal, (actor.CalcSeqOverride or -1)
  end

  --- Translates an activity into the animation that the Flux animation tables define for the
  -- player's model, weapon hold type and weapon state. On the ground this is the lowered or
  -- raised movement animation, in the air the jump, glide, swim or noclip animation and in a
  -- vehicle the sitting animation. Models without an animation table are handled by the base
  -- gamemode.
  -- @param actor [Player]
  -- @param act [Number activity to translate, ACT_ enum]
  -- @return [Number translated activity or sequence ID, or nil if the tables have no match]
  function GM:TranslateActivity(actor, act)
    local animations = actor.fl_anim_table

    if !animations then
      return self.BaseClass:TranslateActivity(actor, act)
    end

    actor.CalcSeqOverride = -1

    if actor:InVehicle() then
      local vehicles = animations.vehicle
      local entry = vehicles and vehicles[actor:GetVehicle():GetClass()]

      if entry then
        local position = entry[2]

        if position then
          actor:ManipulateBonePosition(0, position)
          actor.should_reset_position = true
        end

        local anim, is_sequence = resolve(actor, animations, entry[1])

        if is_sequence then
          actor.CalcSeqOverride = anim
        end

        return anim
      end

      local pair = animations.normal[ACT_MP_CROUCH_IDLE]

      return pair and pair[1]
    end

    if actor.should_reset_position then
      actor:ManipulateBonePosition(0, vector_origin)
      actor.should_reset_position = nil
    end

    local anims = hold_type_animations(actor, animations)
    local anim

    if actor:OnGround() then
      local pair = anims[act] or anims[ACT_MP_STAND_IDLE]

      if !pair then return end

      --- Asks whether a player should use the raised weapon animations of their model.
      -- Called on both realms whenever the gamemode translates a movement activity of a
      -- player who is on the ground and whose model has a Flux animation table. Gamemode
      -- (`GM`) handlers are not called.
      -- @param actor [Player The player being animated]
      -- @param model [String Path of the model the player's animation table belongs to]
      -- @return [Boolean Return true to use the raised animations; the lowered ones are used
      --   when nothing or false is returned]
      if hook.Call('ModelWeaponRaised', nil, actor, actor.fl_anim_model) then
        anim = pair[2]
      else
        anim = pair[1]
      end
    elseif act == ACT_MP_SWIM then
      anim = anims.swim or anims.glide
    elseif actor.m_bWasNoclipping then
      anim = anims.noclip or anims.glide
    elseif act == ACT_MP_JUMP and anims.jump and actor:GetVelocity()[3] > 0 then
      anim = anims.jump
    else
      anim = anims.glide
    end

    if !anim then return end

    local is_sequence
    anim, is_sequence = resolve(actor, animations, anim)

    if is_sequence then
      actor.CalcSeqOverride = anim
    end

    return anim
  end

  --- Plays the attack and reload gestures of the player's hold type, with their crouched
  -- variants where the animation table has them, handles the jump and reload cancel events
  -- and plays the gestures sent with Player#play_gesture. Models without an animation table
  -- use the default player gestures.
  -- @param actor [Player]
  -- @param event [Number animation event, PLAYERANIMEVENT_ enum]
  -- @param data [Number data of the event; the activity or sequence of a custom gesture]
  -- @return [Number activity for the view model or ACT_INVALID; nil for unhandled events]
  function GM:DoAnimationEvent(actor, event, data)
    if event == PLAYERANIMEVENT_CUSTOM_GESTURE then
      actor:AnimRestartGesture(GESTURE_SLOT_CUSTOM, data, true)

      return ACT_INVALID
    elseif event == PLAYERANIMEVENT_CUSTOM_GESTURE_SEQUENCE then
      actor:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, data, 0, true)

      return ACT_INVALID
    end

    local animations = actor.fl_anim_table

    if event == PLAYERANIMEVENT_ATTACK_PRIMARY then
      if animations then
        local anims = hold_type_animations(actor, animations)
        local anim = actor:Crouching() and anims.attack_low or anims.attack

        if anim then
          restart_gesture(actor, animations, GESTURE_SLOT_ATTACK_AND_RELOAD, anim)
        end
      elseif actor:Crouching() then
        actor:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_CROUCH_PRIMARYFIRE, true)
      else
        actor:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_ATTACK_STAND_PRIMARYFIRE, true)
      end

      return ACT_VM_PRIMARYATTACK
    elseif event == PLAYERANIMEVENT_ATTACK_SECONDARY then
      if animations then
        local anims = hold_type_animations(actor, animations)
        local anim = anims.attack_secondary or (actor:Crouching() and anims.attack_low) or anims.attack

        if anim then
          restart_gesture(actor, animations, GESTURE_SLOT_ATTACK_AND_RELOAD, anim)
        end
      end

      return ACT_VM_SECONDARYATTACK
    elseif event == PLAYERANIMEVENT_RELOAD then
      if animations then
        local anims = hold_type_animations(actor, animations)
        local anim = actor:Crouching() and anims.reload_low or anims.reload

        if anim then
          restart_gesture(actor, animations, GESTURE_SLOT_ATTACK_AND_RELOAD, anim)
        end
      elseif actor:Crouching() then
        actor:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_CROUCH, true)
      else
        actor:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_MP_RELOAD_STAND, true)
      end

      return ACT_INVALID
    elseif event == PLAYERANIMEVENT_JUMP then
      actor.m_bJumping = true
      actor.m_bFirstJumpFrame = true
      actor.m_flJumpStartTime = CurTime()

      actor:AnimRestartMainSequence()

      return ACT_INVALID
    elseif event == PLAYERANIMEVENT_CANCEL_RELOAD then
      actor:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD)

      return ACT_INVALID
    end
  end

  --- Keeps the playback rate handling of the base gamemode and, on the server, plays one of
  -- the idle fidget gestures of the animation table every once in a while when the player
  -- stands still on the ground. Does nothing for tables without fidgets.
  -- @param actor [Player]
  -- @param velocity [Vector velocity of the player]
  -- @param max_seq_ground_speed [Number ground speed of the current sequence]
  function GM:UpdateAnimation(actor, velocity, max_seq_ground_speed)
    self.BaseClass:UpdateAnimation(actor, velocity, max_seq_ground_speed)

    if CLIENT then return end

    local animations = actor.fl_anim_table

    if !animations or !animations.has_fidgets then return end

    local cur_time = CurTime()
    local next_fidget = actor.fl_next_fidget
    local interval = animations.fidget_interval

    if !next_fidget then
      actor.fl_next_fidget = cur_time + math.Rand(interval[1], interval[2])
    elseif cur_time >= next_fidget then
      actor.fl_next_fidget = cur_time + math.Rand(interval[1], interval[2])

      if actor.CalcIdeal == ACT_MP_STAND_IDLE and !actor.fl_animation
      and actor:OnGround() and !actor:InVehicle() then
        local fidgets = hold_type_animations(actor, animations).fidgets

        if fidgets and #fidgets > 0 then
          actor:play_gesture(fidgets[math.random(#fidgets)])
        end
      end
    end
  end

  --- Plays the raise or lower gesture of the weapon's hold type when the raised state of
  -- the player's weapon changes. Only runs on the server, where the state is changed.
  -- @param actor [Player]
  -- @param weapon [Weapon weapon that was raised or lowered]
  -- @param raised [Boolean new state]
  function GM:OnWeaponRaised(actor, weapon, raised)
    local animations = actor.fl_anim_table

    if !animations or actor.fl_raised_state == raised then return end

    actor.fl_raised_state = raised

    local anims = hold_type_animations(actor, animations, weapon)
    local gesture

    if raised then
      gesture = anims.raise
    else
      gesture = anims.lower
    end

    if gesture then
      actor:play_gesture(gesture)
    end
  end

  --- Assigns the compiled animation table of the new model to the player and, on the client,
  -- disables inverse kinematics for them. Does nothing if no new model is given.
  -- @param target [Player]
  -- @param new_model [String path of the new model]
  -- @param old_model [String path of the previous model]
  function GM:PlayerModelChanged(target, new_model, old_model)
    if !new_model then return end

    if CLIENT then
      target:SetIK(false)
    end

    target.fl_anim_model = new_model
    target.fl_anim_table = Flux.Anim:get_table(new_model)
    target.fl_raised_state = nil
    target.fl_next_fidget = nil
  end
end

--- Decides whether a player may toggle noclip by asking the plugins through the
-- PlayerEnterNoclip and PlayerExitNoclip hooks. Allowed if no plugin returns a value.
-- @param actor [Player]
-- @param state [Boolean true when entering noclip, false when leaving it]
-- @return [Boolean whether the change is allowed]
function GM:PlayerNoClip(actor, state)
  if state == false then
    --- Called on both realms when a player tries to leave noclip. Gamemode (`GM`) handlers
    -- are not called.
    -- @param actor [Player The player leaving noclip]
    -- @return [Boolean Return false to prevent it or true to allow it; it is allowed when
    --   nothing is returned]
    local should_exit = Plugin.call('PlayerExitNoclip', actor)

    if should_exit != nil then
      return should_exit
    end
  else
    --- Called on both realms when a player tries to enter noclip. Gamemode (`GM`) handlers
    -- are not called. A handler that returns false may put the player into a noclip mode
    -- of its own, which is how the observer plugin works.
    -- @param actor [Player The player entering noclip]
    -- @return [Boolean Return false to prevent it or true to allow it; it is allowed when
    --   nothing is returned]
    local should_enter = Plugin.call('PlayerEnterNoclip', actor)

    if should_enter != nil then
      return should_enter
    end
  end

  return true
end

--- Lets players with the physgun_pickup permission pick entities up with the physics gun,
-- and players without it when a PlayerCanPhysgunPickup handler allows it. Plugins that want
-- to refuse a pickup return false from PhysgunPickup; they do not return true from it, as
-- that would keep the other handlers from refusing.
-- @param actor [Player]
-- @param entity [Entity the entity being picked up]
-- @return [Boolean true if the player may pick the entity up, nil otherwise]
function GM:PhysgunPickup(actor, entity)
  if actor:can('physgun_pickup') then
    return true
  end

  --- Asks whether a player who lacks the physgun_pickup permission may pick an entity up
  -- with the physics gun all the same, for instance because they own it. Called on both the
  -- server and the client after every PhysgunPickup handler has had the chance to refuse.
  -- @param actor [Player The player holding the physics gun]
  -- @param entity [Entity The entity being picked up]
  -- @return [Boolean Return true to allow the pickup]
  if hook.Run('PlayerCanPhysgunPickup', actor, entity) == true then
    return true
  end
end

concommand.Add('fl_save_pers', function()
  if Flux.development and SERVER then
    --- Sandbox's `PersistenceSave` hook, which saves the persistent entities. Flux runs it
    -- on demand from the `fl_save_pers` console command, on the server and in development
    -- only.
    hook.Run('PersistenceSave')
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
    Flux.Anim:invalidate()

    for k, v in player.Iterator() do
      self:PlayerModelChanged(v, v:GetModel(), v:GetModel())
    end
  end

  print('Auto-Reloaded')
end

-- Utility timers to call hooks that should be executed every once in a while.
timer.Create('fl_one_minute', 60, 0, function()
  --- Called once a minute on both realms.
  hook.Run('OneMinute')

  local i = 0

  for k, v in player.Iterator() do
    i = i + 1

    timer.Simple(0.25 * i, function()
      if IsValid(v) then
        --- Called once a minute for every player, on both realms. The calls are spread out:
        -- each player's call comes a quarter of a second after the previous player's.
        -- @param actor [Player The player the call is for]
        hook.Run('PlayerOneMinute', v)
      end
    end)
  end
end)

timer.Create('fl_one_second', 1, 0, function()
  --- Called once a second on both realms. On the server the gamemode's handler uses it to
  -- trigger the periodic data save (`FLSaveData`) and the restart of an empty server.
  hook.Run('OneSecond')
end)

timer.Create('fl_half_second', 0.5, 0, function()
  --- Called twice a second on both realms.
  hook.Run('HalfSecond')
end)

timer.Create('fl_lazy_tick', 0.125, 0, function()
  --- Called eight times a second on both realms. A cheaper alternative to `Tick` and
  -- `Think` for work that has to happen often, but not on every tick or frame.
  hook.Run('LazyTick')
end)
