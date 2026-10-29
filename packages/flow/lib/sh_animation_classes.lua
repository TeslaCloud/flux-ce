--- Animation classes for models built on the skeletons of the stock Half-Life 2 NPCs:
-- 'metrocop' (metropolice), 'combine_soldier' (combine soldiers), 'vortigaunt' and 'zombie'
-- (both without weapon animations). A faction assigns them to its models in `model_classes`.
-- @module [Flux.Anim]

const metrocop_vehicles = {
  prop_vehicle_prisoner_pod = { ACT_IDLE, Vector(0, 0, 0) },
  prop_vehicle_jeep         = { ACT_COVER_SMG1_LOW, Vector(15, 0, 0) },
  prop_vehicle_airboat      = { ACT_COVER_SMG1_LOW, Vector(10, 0, -5) }
}

Flux.Anim:register('metrocop', {
  jump = ACT_JUMP,
  normal = {
    [ACT_MP_STAND_IDLE]  = { ACT_IDLE, ACT_IDLE_ANGRY_MELEE },
    [ACT_MP_CROUCH_IDLE] = ACT_COVER_PISTOL_LOW,
    [ACT_MP_WALK]        = { ACT_WALK, ACT_WALK_ANGRY },
    [ACT_MP_CROUCHWALK]  = ACT_WALK_CROUCH,
    [ACT_MP_RUN]         = ACT_RUN,
    attack = ACT_MELEE_ATTACK_SWING_GESTURE
  },
  pistol = {
    [ACT_MP_STAND_IDLE]  = { ACT_IDLE_PISTOL, ACT_IDLE_ANGRY_PISTOL },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_PISTOL_LOW, ACT_RANGE_AIM_PISTOL_LOW },
    [ACT_MP_WALK]        = { ACT_WALK_PISTOL, ACT_WALK_AIM_PISTOL },
    [ACT_MP_RUN]         = { ACT_RUN_PISTOL, ACT_RUN_AIM_PISTOL },
    attack     = ACT_GESTURE_RANGE_ATTACK_PISTOL,
    attack_low = ACT_RANGE_ATTACK_PISTOL_LOW,
    reload     = ACT_GESTURE_RELOAD_PISTOL,
    reload_low = ACT_RELOAD_PISTOL_LOW,
    raise      = ACT_METROPOLICE_DRAW_PISTOL
  },
  smg = {
    [ACT_MP_STAND_IDLE]  = { ACT_IDLE_SMG1, ACT_IDLE_ANGRY_SMG1 },
    [ACT_MP_CROUCH_IDLE] = { ACT_COVER_SMG1_LOW, ACT_RANGE_AIM_SMG1_LOW },
    [ACT_MP_WALK]        = { ACT_WALK_RIFLE, ACT_WALK_AIM_RIFLE },
    [ACT_MP_RUN]         = { ACT_RUN_RIFLE, ACT_RUN_AIM_RIFLE },
    attack     = ACT_GESTURE_RANGE_ATTACK_SMG1,
    attack_low = ACT_RANGE_ATTACK_SMG1_LOW,
    reload     = ACT_GESTURE_RELOAD_SMG1,
    reload_low = ACT_RELOAD_SMG1_LOW
  },
  grenade = {
    attack = ACT_COMBINE_THROW_GRENADE
  },
  melee = {
    attack = ACT_MELEE_ATTACK_SWING_GESTURE,
    raise  = ACT_ACTIVATE_BATON,
    lower  = ACT_DEACTIVATE_BATON
  },
  vehicle = metrocop_vehicles
})

const combine_soldier_rifle = {
  [ACT_MP_STAND_IDLE]  = { ACT_IDLE_SMG1, ACT_IDLE_ANGRY_SMG1 },
  [ACT_MP_CROUCH_IDLE] = { ACT_CROUCHIDLE, ACT_RANGE_AIM_SMG1_LOW },
  [ACT_MP_WALK]        = { ACT_WALK_RIFLE, ACT_WALK_AIM_RIFLE },
  [ACT_MP_CROUCHWALK]  = ACT_WALK_CROUCH_RIFLE,
  [ACT_MP_RUN]         = { ACT_RUN_RIFLE, ACT_RUN_AIM_RIFLE },
  attack     = ACT_GESTURE_RANGE_ATTACK_SMG1,
  attack_low = ACT_RANGE_ATTACK_SMG1_LOW,
  reload     = ACT_GESTURE_RELOAD_SMG1,
  reload_low = ACT_RELOAD_LOW
}

Flux.Anim:register('combine_soldier', {
  jump = ACT_JUMP,
  normal = {
    [ACT_MP_STAND_IDLE]  = { ACT_IDLE_UNARMED, ACT_IDLE_ANGRY },
    [ACT_MP_CROUCH_IDLE] = ACT_CROUCHIDLE,
    [ACT_MP_WALK]        = { ACT_WALK_UNARMED, ACT_WALK_RIFLE },
    [ACT_MP_CROUCHWALK]  = ACT_WALK_CROUCH_RIFLE,
    [ACT_MP_RUN]         = { ACT_RUN_RIFLE, ACT_RUN_AIM_RIFLE },
    attack = ACT_MELEE_ATTACK1,
    reload = ACT_GESTURE_RELOAD
  },
  pistol = combine_soldier_rifle,
  smg = combine_soldier_rifle,
  shotgun = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE_SMG1, ACT_IDLE_ANGRY_SHOTGUN },
    [ACT_MP_WALK]       = { ACT_WALK_RIFLE, ACT_WALK_AIM_SHOTGUN },
    [ACT_MP_RUN]        = { ACT_RUN_RIFLE, ACT_RUN_AIM_SHOTGUN },
    attack     = ACT_GESTURE_RANGE_ATTACK_SHOTGUN,
    attack_low = ACT_RANGE_ATTACK_SHOTGUN_LOW,
    reload     = ACT_GESTURE_RELOAD
  },
  ar2 = {
    [ACT_MP_CROUCH_IDLE] = { ACT_CROUCHIDLE, ACT_RANGE_AIM_AR2_LOW },
    attack     = ACT_GESTURE_RANGE_ATTACK_AR2,
    attack_low = ACT_RANGE_ATTACK_AR2_LOW,
    reload     = ACT_GESTURE_RELOAD
  },
  grenade = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE, ACT_IDLE_ANGRY },
    attack = ACT_COMBINE_THROW_GRENADE
  },
  melee = {
    [ACT_MP_STAND_IDLE] = { ACT_IDLE, ACT_IDLE_ANGRY },
    attack = ACT_MELEE_ATTACK1
  }
})

const creature = {
  land = false,
  glide = ACT_IDLE,
  normal = {
    [ACT_MP_STAND_IDLE]  = ACT_IDLE,
    [ACT_MP_CROUCH_IDLE] = ACT_IDLE,
    [ACT_MP_WALK]        = ACT_WALK,
    [ACT_MP_CROUCHWALK]  = ACT_WALK,
    [ACT_MP_RUN]         = ACT_RUN,
    attack = ACT_MELEE_ATTACK1,
    reload = false
  }
}

Flux.Anim:register('vortigaunt', creature)
Flux.Anim:register('zombie', creature)
