mod 'Flux::Anim'

local stored      = Flux.Anim.stored or {}
local models      = Flux.Anim.models or {}
Flux.Anim.stored  = stored
Flux.Anim.models  = models

stored.player = {
  normal = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE, ACT_IDLE_ANGRY_SMG1 },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_LOW, ACT_COVER_LOW },
    [ACT_MP_WALK] = { ACT_WALK, ACT_WALK_AIM_RIFLE_STIMULATED },
    [ACT_MP_CROUCHWALK] = { ACT_WALK_CROUCH, ACT_WALK_CROUCH_AIM_RIFLE },
    [ACT_MP_RUN] = { ACT_RUN, ACT_RUN_AIM_RIFLE_STIMULATED },
    glide = ACT_GLIDE
  },
  pistol = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE, ACT_RANGE_ATTACK_PISTOL },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_LOW, ACT_RANGE_ATTACK_PISTOL_LOW },
    [ACT_MP_WALK] = { ACT_WALK, ACT_WALK_AIM_RIFLE_STIMULATED },
    [ACT_MP_CROUCHWALK] = { ACT_WALK_CROUCH, ACT_WALK_CROUCH_AIM_RIFLE },
    [ACT_MP_RUN] = { ACT_RUN, ACT_RUN_AIM_RIFLE_STIMULATED },
    attack = ACT_GESTURE_RANGE_ATTACK_PISTOL,
    reload = ACT_RELOAD_PISTOL
  },
  smg = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE_SMG1_RELAXED, ACT_IDLE_ANGRY_SMG1 },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_LOW_RPG, ACT_RANGE_AIM_SMG1_LOW },
    [ACT_MP_WALK] = { ACT_WALK_RIFLE_RELAXED, ACT_WALK_AIM_RIFLE_STIMULATED },
    [ACT_MP_CROUCHWALK] = { ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH_AIM_RIFLE },
    [ACT_MP_RUN] = { ACT_RUN_RIFLE, ACT_RUN_AIM_RIFLE_STIMULATED },
    attack = ACT_GESTURE_RANGE_ATTACK_SMG1,
    reload = ACT_GESTURE_RELOAD_SMG1
  },
  shotgun = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE_SHOTGUN_RELAXED, ACT_IDLE_ANGRY_SMG1 },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_LOW_RPG, ACT_RANGE_AIM_SMG1_LOW },
    [ACT_MP_WALK] = { ACT_WALK_RIFLE_RELAXED, ACT_WALK_AIM_RIFLE_STIMULATED },
    [ACT_MP_CROUCHWALK] = { ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH_RIFLE },
    [ACT_MP_RUN] = { ACT_RUN_RIFLE_RELAXED, ACT_RUN_AIM_RIFLE_STIMULATED },
    attack = ACT_GESTURE_RANGE_ATTACK_SHOTGUN
  },
  grenade = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE, ACT_IDLE_MANNEDGUN },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_LOW, ACT_COVER_PISTOL_LOW },
    [ACT_MP_WALK] = { ACT_WALK, ACT_WALK_AIM_RIFLE_STIMULATED },
    [ACT_MP_CROUCHWALK] = { ACT_WALK_CROUCH, ACT_WALK_CROUCH_AIM_RIFLE },
    [ACT_MP_RUN] = { ACT_RUN, ACT_RUN_RIFLE_STIMULATED },
    attack = ACT_RANGE_ATTACK_THROW
  },
  melee = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE_SUITCASE, ACT_IDLE_ANGRY_MELEE },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_LOW, ACT_COVER_LOW },
    [ACT_MP_WALK] = { ACT_WALK, ACT_WALK_AIM_RIFLE },
    [ACT_MP_CROUCHWALK] = { ACT_WALK_CROUCH, ACT_WALK_CROUCH },
    [ACT_MP_RUN] = { ACT_RUN, ACT_RUN },
    attack = ACT_MELEE_ATTACK_SWING
  },
  rpg = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE_RPG_RELAXED, ACT_IDLE_ANGRY_SMG1 },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_LOW_RPG, ACT_COVER_LOW_RPG },
    [ACT_MP_WALK] = { ACT_WALK_RPG_RELAXED, ACT_WALK_RPG },
    [ACT_MP_CROUCHWALK] = ACT_WALK_CROUCH_RPG,
    [ACT_MP_RUN] = { ACT_RUN_RPG_RELAXED, ACT_RUN_RPG },
    attack = ACT_RANGE_ATTACK_RPG
  },
  ar2 = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE_SHOTGUN_RELAXED, ACT_IDLE_AIM_RIFLE_STIMULATED },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_LOW_RPG, ACT_RANGE_AIM_AR2_LOW },
    [ACT_MP_WALK] = { ACT_WALK_RIFLE_RELAXED, ACT_WALK_AIM_RIFLE_STIMULATED },
    [ACT_MP_CROUCHWALK] = { ACT_WALK_CROUCH, ACT_WALK_CROUCH_AIM_RIFLE },
    [ACT_MP_RUN] = { ACT_RUN_RIFLE_RELAXED, ACT_RUN_AIM_RIFLE_STIMULATED },
    attack = ACT_GESTURE_RANGE_ATTACK_AR2,
    reload = ACT_GESTURE_RELOAD_SMG1
  },
  vehicle = {
    prop_vehicle_prisoner_pod = { 'podpose', Vector(-3, 0, 0) },
    prop_vehicle_jeep = { 'sitchair1', Vector(13, 0, -16.5) },
    prop_vehicle_airboat = { 'sitchair1', Vector(8, 0, -20) }
  }
}

--- Returns all of the animation tables.
-- @return [Map animation tables by model class]
function Flux.Anim:all()
  return stored
end

--- Sets which animation table a model uses. Falls back to the 'player' class
-- if the specified class does not exist.
-- @param model [String path to the model]
-- @param class [String model class, a key of the table returned by Flux.Anim#all]
function Flux.Anim:set_model_class(model, class)
  if !stored[class] then
    class = 'player'
  end

  models[string.lower(model)] = class
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

--- Returns the animation table of a model. Models from a 'player' folder do not get one,
-- as they use the default player animations.
-- @param model [String path to the model]
-- @return [Map animations by hold type, or nil if the model does not need them]
function Flux.Anim:get_table(model)
  if !model then return end

  if string.find(model, '/player/') then
    return
  end

  return stored[self:get_model_class(model)]
end

do
  local translate_hold_types = {
    ['']                  = 'normal',
    ['slam']              = 'normal',
    ['grenade']           = 'normal',
    ['fist']              = 'normal',
    ['passive']           = 'normal',
    ['magic']             = 'normal',
    ['physgun']           = 'smg',
    ['ar2']               = 'smg',
    ['camera']            = 'smg',
    ['crossbow']          = 'shotgun',
    ['rpg']               = 'shotgun',
    ['melee2']            = 'melee',
    ['knife']             = 'melee',
    ['duel']              = 'pistol',
    ['revolver']          = 'pistol'
  }

  local weapon_hold_types = {
    ['weapon_ar2']        = 'smg',
    ['weapon_smg1']       = 'smg',
    ['weapon_physgun']    = 'smg',
    ['weapon_crossbow']   = 'smg',
    ['weapon_physcannon'] = 'smg',
    ['weapon_crowbar']    = 'melee',
    ['weapon_bugbait']    = 'melee',
    ['weapon_stunstick']  = 'melee',
    ['weapon_stunstick']  = 'melee',
    ['gmod_tool']         = 'pistol',
    ['weapon_357']        = 'pistol',
    ['weapon_pistol']     = 'pistol',
    ['weapon_frag']       = 'grenade',
    ['weapon_slam']       = 'grenade',
    ['weapon_rpg']        = 'shotgun',
    ['weapon_shotgun']    = 'shotgun',
    ['weapon_annabelle']  = 'shotgun'
  }

  --- Returns the hold type of a weapon translated to one of the hold types used by
  -- the animation tables.
  -- @param owner [Player the player who holds the weapon, currently unused]
  -- @param weapon [Weapon]
  -- @return [String lower case hold type, 'normal' if the weapon is not valid]
  function Flux.Anim.get_weapon_hold_type(owner, weapon)
    if !IsValid(weapon) then return 'normal' end

    local translated_hold_type = weapon_hold_types[string.lower(weapon:GetClass())]
    local hold_type = 'normal'

    if translated_hold_type then
      hold_type = translated_hold_type
    elseif weapon and weapon.HoldType then
      translated_hold_type = translate_hold_types[weapon.HoldType]

      if translated_hold_type then
        hold_type = translated_hold_type
      else
        hold_type = weapon.HoldType
      end
    end

    return string.lower(hold_type)
  end
end

local player_meta = FindMetaTable('Player')

--- Makes the player play the specified sequence instead of their regular animations.
-- The override is removed once the sequence has finished.
-- @param animation [String name of the sequence]
-- @param duration_override=nil [Number seconds to keep the override for instead of
--   the duration of the sequence, 0 keeps it until Player#stop_animation is called]
function player_meta:set_animation(animation, duration_override)
  local sequence, duration = self:LookupSequence(animation)

  if duration_override then
    duration = duration_override
  end

  if sequence != -1 then
    self:SetCycle(0)
    self.fl_animation = sequence

    if duration > 0 then
      timer.simple(duration, function()
        if IsValid(self) then
          self.fl_animation = nil
        end
      end)
    end
  end
end

--- Stops the animation that was set with Player#set_animation.
function player_meta:stop_animation()
  self.fl_animation = nil
end
