--- The animations that the plugin registers: stances and gestures of the citizen models and
-- of the Civil Protection models. Which of them a player is offered depends on the
-- sequences their model has, so each model only lists its own.
--
-- The sequence names were checked against the animation models of Half-Life 2: the citizen
-- ones are in `models/humans/male_shared.mdl`, `female_shared.mdl`, `male_ss.mdl` and
-- `female_ss.mdl`, the Civil Protection ones in `models/police_animations.mdl` and
-- `models/police_ss.mdl`. Sequence names are matched without regard to case.

Animations:register_anim({
  id = 'sit_ground',
  name = 'animation.sit_ground.name',
  enter = 'idle_to_sit_ground',
  anim = 'sit_ground',
  exit = 'sit_ground_to_idle'
})

Animations:register_anim({
  id = 'sit_wall',
  name = 'animation.sit_wall.name',
  anim = 'plazaidle4',
  wall = 'behind',
  wall_height = 16
})

Animations:register_anim({
  id = 'lean_back',
  name = 'animation.lean_back.name',
  anim = 'lean_back',
  wall = 'behind'
})

Animations:register_anim({
  id = 'lean_arms_back',
  name = 'animation.lean_arms_back.name',
  anim = 'plazaidle2',
  wall = 'behind'
})

Animations:register_anim({
  id = 'lean_arms_down',
  name = 'animation.lean_arms_down.name',
  anim = 'plazaidle1',
  wall = 'behind'
})

Animations:register_anim({
  id = 'idle_1',
  name = 'animation.idle_1.name',
  anim = 'lineidle01'
})

Animations:register_anim({
  id = 'idle_2',
  name = 'animation.idle_2.name',
  anim = 'lineidle02'
})

Animations:register_anim({
  id = 'idle_3',
  name = 'animation.idle_3.name',
  anim = 'lineidle03'
})

Animations:register_anim({
  id = 'idle_4',
  name = 'animation.idle_4.name',
  anim = 'lineidle04'
})

Animations:register_anim({
  id = 'pant',
  name = 'animation.pant.name',
  enter = 'd2_coast03_postbattle_idle02_entry',
  anim = 'd2_coast03_postbattle_idle02'
})

Animations:register_anim({
  id = 'pant_wall',
  name = 'animation.pant_wall.name',
  enter = 'd2_coast03_postbattle_idle01_entry',
  anim = 'd2_coast03_postbattle_idle01',
  wall = 'front'
})

Animations:register_anim({
  id = 'window',
  name = 'animation.window.name',
  anim = { 'd1_t03_tenements_look_out_window_idle', 'd1_t03_lookoutwindow' },
  wall = 'front'
})

Animations:register_anim({
  id = 'cheer',
  name = 'animation.cheer.name',
  anim = { 'cheer1', 'cheer2' },
  one_shot = true
})

Animations:register_anim({
  id = 'wave',
  name = 'animation.wave.name',
  anim = 'wave',
  one_shot = true
})

Animations:register_anim({
  id = 'wave_close',
  name = 'animation.wave_close.name',
  anim = 'wave_close',
  one_shot = true
})

Animations:register_anim({
  id = 'cp_lean',
  name = 'animation.cp_lean.name',
  anim = 'idle_baton',
  wall = 'behind'
})

Animations:register_anim({
  id = 'cp_threat_1',
  name = 'animation.cp_threat_1.name',
  anim = 'plazathreat1'
})

Animations:register_anim({
  id = 'cp_threat_2',
  name = 'animation.cp_threat_2.name',
  anim = 'plazathreat2'
})

Animations:register_anim({
  id = 'cp_deny',
  name = 'animation.cp_deny.name',
  anim = 'harassfront2',
  one_shot = true
})

Animations:register_anim({
  id = 'cp_motion_left',
  name = 'animation.cp_motion_left.name',
  anim = 'motionleft',
  one_shot = true
})

Animations:register_anim({
  id = 'cp_motion_right',
  name = 'animation.cp_motion_right.name',
  anim = 'motionright',
  one_shot = true
})
