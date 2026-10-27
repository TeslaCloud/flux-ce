--- Shared hooks of the Third Person plugin: reads the aim and fire input out of the commands
-- of a player in third person control, keeps track of how long their weapon is to stay
-- raised and takes the secondary attack away from the weapons whose secondary attack the aim
-- takes. On the client it also predicts the raised state of the local player's weapon, so
-- that the Raise Weapon plugin lets the first shot through. On both realms it turns the model
-- of every player in third person control apart from their view angles.
--
-- A command is sent to the server before the client runs it through StartCommand, so the
-- server sees the secondary attack the way the player pressed it and learns of the aim from
-- it; the client takes the key out of its own copy of the command only so that the weapon
-- does not predict a secondary attack.

if CLIENT then
  --- CurTime() until which the local player's weapon is predicted to be raised: the last aim
  -- or fire input of the local player plus `ThirdPerson.raise_grace`. Mirrors the
  -- `fl_tp_raise_until` field the server keeps on every player.
  ThirdPerson.local_raise_until = ThirdPerson.local_raise_until or 0

  --- Predicts the raised state of the local player's weapon while third person control is
  -- in effect: the weapon counts as raised while the aim or fire key is held and for
  -- `ThirdPerson.raise_grace` seconds after it was last held, which the server makes true
  -- shortly after.
  -- The keys are taken from `ThirdPerson.aiming` and `ThirdPerson.firing`, which the
  -- `CreateMove` handler reads out of every command before any StartCommand handler sees
  -- it. They cannot be read in this plugin's own StartCommand handler: the Raise Weapon
  -- plugin loads first, and its handler takes the attack keys out of the command while the
  -- weapon counts as lowered. Answering true as soon as a key is held keeps the keys in the
  -- command, so that the first shot is not lost.
  -- Nothing is answered for other players, outside of the control, while the
  -- `weapon_raise_enabled` config is off or while the player is running and the
  -- `sprint_lowers_weapon` config keeps the weapon lowered, so that the normal state
  -- applies.
  -- @param actor [Player]
  -- @param _weapon [Weapon active weapon of the player, one that can be raised and lowered]
  -- @return [Boolean true while the weapon is predicted to be raised, nil otherwise]
  function ThirdPerson:ShouldWeaponBeRaised(actor, _weapon)
    if actor != PLAYER or !self:is_controlling(actor) then return end
    if !Config.get('weapon_raise_enabled', true) then return end
    if Config.get('sprint_lowers_weapon') and actor:running() then return end

    if self.aiming or self.firing or CurTime() < self.local_raise_until then
      return true
    end
  end
end

--- Reads the aim and fire input out of the commands of a player in third person control and
-- takes the secondary attack out of them for the weapons whose secondary attack the aim
-- takes, so that aiming never fires it. The fists, physgun, gravity gun, tool gun, camera
-- and the weapons the Raise Weapon plugin marks as always or never raised keep it.
-- While the player aims or fires, the raise window is opened again: on the server the
-- `fl_tp_raise_until` field of the player is set to `ThirdPerson.raise_grace` seconds from
-- now and a lowered weapon is raised at once (see `ThirdPerson:update_raise`), on the client
-- `ThirdPerson.local_raise_until` is set for the local player.
-- @param actor [Player]
-- @param user_cmd [CUserCmd]
function ThirdPerson:StartCommand(actor, user_cmd)
  if CLIENT and actor != PLAYER then return end
  if !self:is_controlling(actor) then return end

  local weapon = actor:GetActiveWeapon()
  local aiming, firing = self:read_input(user_cmd:GetButtons(), weapon)

  if aiming or firing then
    local cur_time = CurTime()

    if SERVER then
      actor.fl_tp_raise_until = cur_time + self.raise_grace

      self:update_raise(actor, cur_time)
    else
      self.local_raise_until = cur_time + self.raise_grace
    end
  end

  if self:owns_secondary_attack(weapon) then
    user_cmd:RemoveKey(IN_ATTACK2)
  end
end

--- How fast, in degrees per second, the model of a character turns towards the way they move.
local move_turn_rate = 540

--- How fast, in degrees per second, the model turns towards where the player aims once their
-- weapon is raised.
local aim_turn_rate = 900

--- Horizontal speed, in units per second, under which a character counts as standing still
-- and keeps the way their model faces.
local min_move_speed = 20

--- Turns the model of a player in third person control on its own, apart from their view
-- angles, which follow the camera: towards where they aim while their weapon is raised (see
-- `ThirdPerson:faces_aim`), towards the way they move otherwise, and not at all while they
-- stand still. Runs on the server and on every client from the same networked state, so that
-- everyone sees the model turned the same way.
-- The movement pose parameters (`move_yaw`, `move_x` and `move_y`) are worked out against the
-- way the model faces instead of the view angles, so that the legs match the movement. While
-- the model does not face the aim, the aim and head pose parameters are set straight, so that
-- the upper body does not twist towards the camera; while it does, `aim_yaw` makes up for
-- the part of the turn the model has not made yet.
-- The turn is timed with `UnPredictedCurTime()` per player, so that a player animated twice
-- in a frame does not turn twice as fast.
-- @param actor [Player]
-- @param velocity [Vector velocity of the player]
-- @param _max_seq_ground_speed [Number ground speed of the current sequence]
function ThirdPerson:UpdateAnimation(actor, velocity, _max_seq_ground_speed)
  if !self:is_controlling(actor) then
    actor.fl_tp_body_yaw = nil
    actor.fl_tp_anim_time = nil

    return
  end

  local now = UnPredictedCurTime()
  local delta = math.Clamp(now - (actor.fl_tp_anim_time or now), 0, 0.1)
  local eye_yaw = actor:EyeAngles().y
  local body_yaw = actor.fl_tp_body_yaw or eye_yaw
  local speed = velocity:Length2D()
  local moving = speed > min_move_speed
  local move_yaw = moving and velocity:Angle().y or body_yaw
  local facing_aim = self:faces_aim(actor)

  actor.fl_tp_anim_time = now

  if facing_aim then
    body_yaw = math.ApproachAngle(body_yaw, eye_yaw, aim_turn_rate * delta)
  elseif moving then
    body_yaw = math.ApproachAngle(body_yaw, move_yaw, move_turn_rate * delta)
  end

  body_yaw = math.NormalizeAngle(body_yaw)
  actor.fl_tp_body_yaw = body_yaw

  if actor.SetRenderAngles then
    actor:SetRenderAngles(Angle(0, body_yaw, 0))
  end

  local relative_move = math.rad(math.NormalizeAngle(move_yaw - body_yaw))

  actor:SetPoseParameter('move_yaw', math.deg(relative_move))

  if moving then
    actor:SetPoseParameter('move_x', math.cos(relative_move))
    actor:SetPoseParameter('move_y', -math.sin(relative_move))
  else
    actor:SetPoseParameter('move_x', 0)
    actor:SetPoseParameter('move_y', 0)
  end

  if facing_aim then
    actor:SetPoseParameter('aim_yaw', math.NormalizeAngle(eye_yaw - body_yaw))
  else
    actor:SetPoseParameter('aim_yaw', 0)
    actor:SetPoseParameter('aim_pitch', 0)
    actor:SetPoseParameter('head_yaw', 0)
    actor:SetPoseParameter('head_pitch', 0)
  end
end
