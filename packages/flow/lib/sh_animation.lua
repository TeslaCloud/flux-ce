--- Animations for player models that are not built on the player animation set of Garry's Mod,
-- such as the NPC models that roleplay schemas use for their characters. Every such model is
-- assigned a model class with `Flux.Anim:set_model_class`, and every class has an animation
-- table, registered with `Flux.Anim:register`, that maps movement states and weapon hold types
-- to the activities or sequences of that kind of model. 'player' is the built-in class and the
-- fallback for models without a class. The tables are compiled on first use into a flat form,
-- returned by `Flux.Anim:get_table`, from which the animation hooks of Flux pick the idle,
-- walk, run, crouch, jump, attack and reload animations of a player, depending on the weapon
-- they hold (`Flux.Anim.get_weapon_hold_type`) and on whether it is raised. Models from a
-- 'player' folder keep the regular animations of Garry's Mod.
--
-- The library also adds the `Player` methods for one-off animations: `Player:set_animation`
-- makes a player play a sequence instead of their regular animations, and
-- `Player:play_gesture` plays a gesture on top of them. An animation that the server sets
-- is shown by every client, including the clients of players who join while it lasts; one
-- that a client sets is only seen on that client.
-- @module [Flux.Anim]

mod 'Flux::Anim'

local stored            = Flux.Anim.stored or {}
local models            = Flux.Anim.models or {}
local compiled_classes  = {}
local model_tables      = {}
Flux.Anim.stored        = stored
Flux.Anim.models        = models

local hold_type_parents = {
  pistol  = 'normal',
  smg     = 'normal',
  shotgun = 'smg',
  ar2     = 'smg',
  rpg     = 'shotgun',
  grenade = 'normal',
  melee   = 'normal'
}

local normal_defaults = {
  glide  = ACT_GLIDE,
  land   = ACT_LAND,
  attack = ACT_GESTURE_RANGE_ATTACK_SMG1,
  reload = ACT_GESTURE_RELOAD_SMG1
}

local class_settings = {
  run_speed       = 150,
  fidget_interval = { 15, 40 }
}

local pair_keys = {
  [ACT_MP_STAND_IDLE]  = true,
  [ACT_MP_CROUCH_IDLE] = true,
  [ACT_MP_WALK]        = true,
  [ACT_MP_CROUCHWALK]  = true,
  [ACT_MP_RUN]         = true
}

stored.player = {
  jump = ACT_JUMP,
  normal = {
    [ACT_MP_STAND_IDLE]  = { ACT_IDLE, ACT_IDLE_ANGRY_MELEE },
    [ACT_MP_CROUCH_IDLE] = ACT_COVER_LOW,
    [ACT_MP_WALK]        = ACT_WALK,
    [ACT_MP_CROUCHWALK]  = ACT_WALK_CROUCH,
    [ACT_MP_RUN]         = ACT_RUN,
    attack = ACT_MELEE_ATTACK_SWING
  },
  pistol = {
    [ACT_MP_STAND_IDLE]  = { ACT_IDLE, ACT_RANGE_ATTACK_PISTOL },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_LOW, ACT_RANGE_ATTACK_PISTOL_LOW },
    [ACT_MP_WALK]        = { ACT_WALK, ACT_WALK_AIM_RIFLE_STIMULATED },
    [ACT_MP_CROUCHWALK]  = { ACT_WALK_CROUCH, ACT_WALK_CROUCH_AIM_RIFLE },
    [ACT_MP_RUN]         = { ACT_RUN, ACT_RUN_AIM_RIFLE_STIMULATED },
    attack     = ACT_GESTURE_RANGE_ATTACK_PISTOL,
    attack_low = ACT_RANGE_ATTACK_PISTOL_LOW,
    reload     = ACT_RELOAD_PISTOL,
    reload_low = ACT_RELOAD_PISTOL_LOW
  },
  smg = {
    [ACT_MP_STAND_IDLE]  = { ACT_IDLE_SMG1_RELAXED, ACT_IDLE_ANGRY_SMG1 },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_LOW_RPG, ACT_RANGE_AIM_SMG1_LOW },
    [ACT_MP_WALK]        = { ACT_WALK_RIFLE_RELAXED, ACT_WALK_AIM_RIFLE_STIMULATED },
    [ACT_MP_CROUCHWALK]  = { ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH_AIM_RIFLE },
    [ACT_MP_RUN]         = { ACT_RUN_RIFLE_RELAXED, ACT_RUN_AIM_RIFLE_STIMULATED },
    attack     = ACT_GESTURE_RANGE_ATTACK_SMG1,
    attack_low = ACT_RANGE_ATTACK_SMG1_LOW,
    reload     = ACT_GESTURE_RELOAD_SMG1,
    reload_low = ACT_RELOAD_SMG1_LOW
  },
  shotgun = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE_SHOTGUN_RELAXED, ACT_IDLE_SHOTGUN_AGITATED },
    attack = ACT_GESTURE_RANGE_ATTACK_SHOTGUN
  },
  ar2 = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE_AR2_RELAXED, ACT_IDLE_ANGRY_AR2 },
    [ACT_MP_WALK]       = { ACT_WALK_AR2_RELAXED, ACT_WALK_AIM_AR2_STIMULATED },
    [ACT_MP_RUN]        = { ACT_RUN_AR2_RELAXED, ACT_RUN_AIM_AR2_STIMULATED },
    attack = ACT_GESTURE_RANGE_ATTACK_AR2,
    reload = ACT_GESTURE_RELOAD_AR2
  },
  rpg = {
    [ACT_MP_STAND_IDLE]  = { ACT_IDLE_RPG_RELAXED, ACT_IDLE_ANGRY_RPG },
    [ACT_MP_CROUCH_IDLE] = ACT_COVER_LOW_RPG,
    [ACT_MP_WALK]        = { ACT_WALK_RPG_RELAXED, ACT_WALK_RPG },
    [ACT_MP_CROUCHWALK]  = ACT_WALK_CROUCH_RPG,
    [ACT_MP_RUN]         = { ACT_RUN_RPG_RELAXED, ACT_RUN_RPG },
    attack = ACT_GESTURE_RANGE_ATTACK_RPG
  },
  grenade = {
    attack = ACT_RANGE_ATTACK_THROW
  },
  melee = {
    attack = ACT_MELEE_ATTACK_SWING
  },
  vehicle = {
    prop_vehicle_prisoner_pod = { 'podpose', Vector(-3, 0, 0) },
    prop_vehicle_jeep         = { 'sitchair1', Vector(13, 0, -16.5) },
    prop_vehicle_airboat      = { 'sitchair1', Vector(8, 0, -20) }
  }
}

--- Returns all of the animation tables, as they were registered.
-- @return [Map animation tables by model class]
function Flux.Anim:all()
  return stored
end

--- Registers the animation table of a model class and drops anything compiled from the
-- previous table of that class.
--
-- The table holds one sub-table per weapon hold type ('normal', 'pistol', 'smg', 'shotgun',
-- 'ar2', 'rpg', 'grenade', 'melee' or any custom hold type) and an optional 'vehicle' table
-- mapping vehicle classes to { animation, bone offset } pairs. Hold types inherit every
-- entry they do not define from a parent hold type (ar2 and shotgun from smg, rpg from
-- shotgun, everything else from normal), so a class only has to list what differs. Values
-- placed directly in the class table (such as jump = ACT_JUMP) act as defaults for the
-- normal hold type, except for the settings run_speed (units per second above which the
-- run animation plays) and fidget_interval ({ min, max } seconds between idle fidgets).
--
-- Entries are activities (ACT_ enums) or sequence names. The movement keys ACT_MP_STAND_IDLE,
-- ACT_MP_CROUCH_IDLE, ACT_MP_WALK, ACT_MP_CROUCHWALK and ACT_MP_RUN take a { lowered, raised }
-- pair or a single value used for both weapon states. The other keys are:
--  glide (airborne), jump (rising during a jump, glide if nil), swim, noclip (both glide if
--  nil), land (gesture on landing, false disables it), attack, attack_low (crouched),
--  attack_secondary, reload, reload_low (crouched), raise and lower (gestures played when
--  the weapon is raised or lowered) and fidgets (a list of gestures played at random while
--  standing still).
-- @param class [String model class]
-- @param data [Map animation table]
-- @return [Map the registered table]
function Flux.Anim:register(class, data)
  stored[class] = data
  compiled_classes[class] = nil
  model_tables = {}

  return data
end

--- Sets which animation table a model uses. Falls back to the 'player' class
-- if the specified class does not exist.
-- @param model [String path to the model]
-- @param class [String model class, a key of the table returned by Flux.Anim#all]
function Flux.Anim:set_model_class(model, class)
  if !stored[class] then
    class = 'player'
  end

  model = string.lower(model)
  models[model] = class
  model_tables[model] = nil
end

--- Returns the animation class of a model.
-- @param model [String path to the model]
-- @return [String model class, 'player' if none was set for the model]
function Flux.Anim:get_model_class(model)
  if !model then return 'player' end

  local model_class = models[string.lower(model)]

  if model_class then
    return model_class
  end

  return 'player'
end

--- Drops all compiled animation tables so that they are rebuilt from the registered
-- tables the next time they are needed.
function Flux.Anim:invalidate()
  compiled_classes = {}
  model_tables = {}
end

do
  --- Copies a movement entry into a { lowered, raised } pair of its own.
  -- @param value [Table pair or Number activity or String sequence name]
  -- @return [Table pair]
  local function copy_pair(value)
    if istable(value) then
      return { value[1], value[2] or value[1] }
    end

    return { value, value }
  end

  --- Compiles the animations of one hold type of a class, inheriting from its parent hold
  -- type first so that lookups at runtime are a single table index.
  -- @param class [Map registered animation table]
  -- @param compiled [Map compiled animation table being built]
  -- @param hold_type [String hold type]
  -- @return [Map compiled animations of the hold type]
  local function compile_hold_type(class, compiled, hold_type)
    local result = compiled[hold_type]

    if result then return result end

    result = {}

    if hold_type == 'normal' then
      for k, v in pairs(normal_defaults) do
        result[k] = v
      end

      for k, v in pairs(class) do
        if !istable(v) and class_settings[k] == nil then
          result[k] = v
        end
      end
    else
      local parent = compile_hold_type(class, compiled, hold_type_parents[hold_type] or 'normal')

      for k, v in pairs(parent) do
        if pair_keys[k] then
          result[k] = { v[1], v[2] }
        else
          result[k] = v
        end
      end
    end

    local source = class[hold_type]

    if istable(source) then
      for k, v in pairs(source) do
        if pair_keys[k] then
          result[k] = copy_pair(v)
        else
          result[k] = v
        end
      end
    end

    compiled[hold_type] = result

    return result
  end

  --- Compiles the registered animation table of a class into the flat form used by the
  -- animation hooks: every hold type gets a complete table with the inherited entries
  -- filled in, the settings get their defaults and the vehicle entries are copied.
  -- @param class [String model class]
  -- @return [Map compiled animation table, nil if the class is not registered]
  function Flux.Anim:compile(class)
    local data = stored[class]

    if !data then return end

    local compiled = {
      sequence_ids = {},
      has_fidgets = false
    }

    for k, v in pairs(class_settings) do
      if data[k] != nil then
        compiled[k] = data[k]
      else
        compiled[k] = v
      end
    end

    compile_hold_type(data, compiled, 'normal')

    for hold_type, v in pairs(hold_type_parents) do
      compile_hold_type(data, compiled, hold_type)
    end

    for k, v in pairs(data) do
      if istable(v) and k != 'vehicle' and class_settings[k] == nil and !compiled[k] then
        compile_hold_type(data, compiled, k)
      end
    end

    for k, v in pairs(compiled) do
      if istable(v) and istable(v.fidgets) and #v.fidgets > 0 then
        compiled.has_fidgets = true
      end
    end

    if istable(data.vehicle) then
      local vehicles = {}

      for k, v in pairs(data.vehicle) do
        if istable(v) then
          vehicles[k] = { v[1], v[2] }
        else
          vehicles[k] = { v }
        end
      end

      compiled.vehicle = vehicles
    end

    compiled_classes[class] = compiled

    return compiled
  end
end

--- Returns the compiled animation table of a model. Models from a 'player' folder do not
-- get one, as they use the default player animations.
-- @param model [String path to the model]
-- @return [Map compiled animation table, or nil if the model does not need one]
function Flux.Anim:get_table(model)
  if !model then return end

  model = string.lower(model)

  local cached = model_tables[model]

  if cached != nil then
    return cached or nil
  end

  local result = false

  if !string.find(model, '/player/', 1, true) then
    local class = self:get_model_class(model)
    result = compiled_classes[class] or self:compile(class) or false
  end

  model_tables[model] = result

  return result or nil
end

do
  local translate_hold_types = {
    ['']         = 'normal',
    ['fist']     = 'normal',
    ['passive']  = 'normal',
    ['magic']    = 'normal',
    ['slam']     = 'grenade',
    ['physgun']  = 'smg',
    ['camera']   = 'smg',
    ['crossbow'] = 'shotgun',
    ['melee2']   = 'melee',
    ['knife']    = 'melee',
    ['duel']     = 'pistol',
    ['revolver'] = 'pistol'
  }

  local weapon_hold_types = {
    ['weapon_ar2']        = 'ar2',
    ['weapon_smg1']       = 'smg',
    ['weapon_physgun']    = 'smg',
    ['weapon_crossbow']   = 'smg',
    ['weapon_physcannon'] = 'smg',
    ['weapon_crowbar']    = 'melee',
    ['weapon_bugbait']    = 'melee',
    ['weapon_stunstick']  = 'melee',
    ['gmod_tool']         = 'pistol',
    ['weapon_357']        = 'pistol',
    ['weapon_pistol']     = 'pistol',
    ['weapon_frag']       = 'grenade',
    ['weapon_slam']       = 'grenade',
    ['weapon_rpg']        = 'rpg',
    ['weapon_shotgun']    = 'shotgun',
    ['weapon_annabelle']  = 'shotgun'
  }

  --- Returns the hold type of a weapon translated to one of the hold types used by
  -- the animation tables. The result is cached on the weapon until its HoldType changes.
  -- @param owner [Player the player who holds the weapon, currently unused]
  -- @param weapon [Weapon]
  -- @return [String lower case hold type, 'normal' if the weapon is not valid]
  function Flux.Anim.get_weapon_hold_type(owner, weapon)
    if !IsValid(weapon) then return 'normal' end

    local raw_hold_type = weapon.HoldType
    local cached = weapon.fl_hold_type

    if cached and weapon.fl_hold_type_source == raw_hold_type then
      return cached
    end

    local hold_type = weapon_hold_types[string.lower(weapon:GetClass())]

    if !hold_type then
      if isstring(raw_hold_type) then
        local lowered = string.lower(raw_hold_type)
        hold_type = translate_hold_types[lowered] or lowered
      else
        hold_type = 'normal'
      end
    end

    weapon.fl_hold_type = hold_type
    weapon.fl_hold_type_source = raw_hold_type

    return hold_type
  end
end

local player_meta = FindMetaTable('Player')
local forced = Flux.Anim.forced or {}
Flux.Anim.forced = forced

--- Takes the finish callback off the animation that was set for a player and makes the
-- timer of that animation do nothing.
-- @param target [Player]
-- @return [Function the finish callback, nil if the animation had none]
local function detach_callback(target)
  local callback = target.fl_animation_callback

  target.fl_animation_serial = (target.fl_animation_serial or 0) + 1
  target.fl_animation_callback = nil

  return callback
end

--- Calls the finish callback of a player animation, if it had one.
-- @param callback [Function the finish callback, or nil]
-- @param target [Player]
-- @param completed [Boolean whether the animation was kept for its whole duration]
local function run_callback(callback, target, completed)
  if !isfunction(callback) then return end

  local ok, result = pcall(callback, target, completed)

  if !ok then
    error_with_traceback('Finish callback of a player animation has failed to run!\n'..result)
  end
end

--- Removes the animation that was set for a player. On the server, also tells the clients
-- if they have been shown the animation.
-- @param target [Player]
-- @param completed [Boolean whether the animation was kept for its whole duration]
local function stop_animation(target, completed)
  target:SetCycle(0)
  target.fl_animation = nil

  if SERVER and forced[target] then
    forced[target] = nil

    Cable.send(nil, 'fl_animation_stop', target:EntIndex())
  end

  run_callback(detach_callback(target), target, completed)
end

--- Makes the player play the specified sequence instead of their regular animations.
-- The override is removed once the sequence has finished. Called on the server, the
-- animation is shown by every client, including the clients of players who join while it
-- lasts; called on a client, it is only seen on that client. Setting an animation replaces
-- the one that was set before.
-- ```
-- target:set_animation('idle_to_sit_ground', nil, function(target, completed)
--   if completed then
--     target:set_animation('sit_ground', 0)
--   end
-- end)
-- ```
-- @param animation [String name of the sequence]
-- @param duration_override=nil [Number seconds to keep the override for instead of
--   the duration of the sequence, 0 keeps it until Player#stop_animation is called]
-- @param callback=nil [Function called with the player and a Boolean when the override is
--   removed: true if it was kept for its whole duration, false if it was stopped or
--   replaced before that. Called in the realm the animation was set in]
-- @return [Boolean false if the model of the player has no such sequence, in which case
--   nothing changes and the callback is not called]
function player_meta:set_animation(animation, duration_override, callback)
  local sequence, duration = self:LookupSequence(animation)

  if sequence == -1 then return false end

  if duration_override then
    duration = duration_override
  end

  local previous_callback = detach_callback(self)
  local serial = self.fl_animation_serial

  self:SetCycle(0)
  self.fl_animation = sequence
  self.fl_animation_callback = callback

  if SERVER then
    forced[self] = animation

    Cable.send(nil, 'fl_animation_set', self:EntIndex(), animation)
  end

  if duration > 0 then
    timer.Simple(duration, function()
      if IsValid(self) and self.fl_animation_serial == serial then
        stop_animation(self, true)
      end
    end)
  end

  run_callback(previous_callback, self, false)

  return true
end

--- Stops the animation that was set with Player#set_animation. Called on the server, it
-- stops on every client as well. The finish callback of the animation is called with false.
function player_meta:stop_animation()
  stop_animation(self, false)
end

if SERVER then
  Cable.check_networked_string('fl_animation_set')
  Cable.check_networked_string('fl_animation_stop')

  --- Hook handlers of the animation library, registered as `FLAnimations`.
  local hooks = {}

  --- Shows a player who has finished loading the animations that were set before they
  -- joined and are still playing.
  -- @param actor [Player]
  function hooks:PlayerInitialized(actor)
    for target, animation in pairs(forced) do
      if IsValid(target) then
        Cable.send(actor, 'fl_animation_set', target:EntIndex(), animation)
      else
        forced[target] = nil
      end
    end
  end

  --- Ends the animation of a leaving player, so that clients forget it and its finish
  -- callback runs.
  -- @param actor [Player]
  function hooks:PlayerDisconnected(actor)
    if forced[actor] then
      stop_animation(actor, false)
    end
  end

  Plugin.add_hooks('FLAnimations', hooks)
else
  local desired = {}

  --- Applies the animation that the server has set for a player, if their model has it.
  -- Leaves the local player alone when they already play it, which is the case when the
  -- same animation was started on this client ahead of the server.
  -- @param target [Entity the player]
  local function apply_animation(target)
    local animation = desired[target:EntIndex()]

    if !animation or !target:IsPlayer() then return end

    local sequence = target:LookupSequence(animation)

    if sequence == -1 then return end
    if target == LocalPlayer() and target.fl_animation == sequence then return end

    local previous_callback = detach_callback(target)

    target:SetCycle(0)
    target.fl_animation = sequence

    run_callback(previous_callback, target, false)
  end

  Cable.receive('fl_animation_set', function(ent_index, animation)
    desired[ent_index] = animation

    util.wait_for_ent(ent_index, apply_animation)
  end)

  Cable.receive('fl_animation_stop', function(ent_index)
    local target = Entity(ent_index)

    desired[ent_index] = nil

    if IsValid(target) and target.fl_animation then
      target:SetCycle(0)
      target.fl_animation = nil

      run_callback(detach_callback(target), target, false)
    end
  end)

  --- Hook handlers of the animation library, registered as `FLAnimations`.
  local hooks = {}

  --- Applies the animation that the server has set for a player once the player comes into
  -- view, in case their model was not available when the animation was announced.
  -- @param entity [Entity entity that starts or stops being networked to this client]
  -- @param should_transmit [Boolean true if it starts being networked]
  function hooks:NotifyShouldTransmit(entity, should_transmit)
    if should_transmit and desired[entity:EntIndex()] and !entity.fl_animation then
      timer.Simple(0, function()
        if IsValid(entity) and !entity.fl_animation then
          apply_animation(entity)
        end
      end)
    end
  end

  Plugin.add_hooks('FLAnimations', hooks)
end

--- Plays a gesture on top of the player's regular animations in the custom gesture slot.
-- Called serverside, the gesture is sent to every client through the animation event
-- system, so this is the way to make everyone see a one-off animation such as a punch,
-- a wave or a weapon draw.
-- @param animation [Number activity (ACT_ enum) or String sequence name]
-- @return [Boolean false if the player's model has no such sequence]
function player_meta:play_gesture(animation)
  if isstring(animation) then
    local sequence = self:LookupSequence(animation)

    if sequence == -1 then return false end

    self:DoCustomAnimEvent(PLAYERANIMEVENT_CUSTOM_GESTURE_SEQUENCE, sequence)
  elseif isnumber(animation) then
    self:DoCustomAnimEvent(PLAYERANIMEVENT_CUSTOM_GESTURE, animation)
  else
    return false
  end

  return true
end
