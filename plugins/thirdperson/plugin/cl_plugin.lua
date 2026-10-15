--- Client side of the Third Person plugin: the GTA V style camera, which orbits the character
-- with angles of its own, the facing of the character, which follows the movement input or,
-- while aiming and firing, the crosshair, the rule that hides the crosshair, the client settings
-- of the camera and the key binds.
--
-- The camera is turned by the mouse in CreateMove, which keeps the camera angles itself and
-- sends the facing of the character as the view angles of the command. The view angles of the
-- player are therefore the direction the character faces and aims in, while the camera shows
-- the world from its own angles.

--- Seconds the camera takes to move between the first and the third person view.
local blend_duration = 0.15

--- Offsets of the camera from the eyes of the character, in units, while not aiming: how far it
-- is to the side (towards the shoulder) and above. How far back it is comes from the
-- `thirdperson_distance` client setting.
local idle_side = 25
local idle_up = 5
local default_distance = 90

--- Offsets of the camera while aiming: how far back, to the side and above it is, and how much
-- the field of view is narrowed, in degrees.
local aim_distance = 45
local aim_side = 20
local aim_up = 5
local aim_fov = -10

--- How fast the offsets and the field of view of the camera follow their targets; the higher,
-- the faster.
local smooth_speed = 10

--- How much of the way back to its wanted spot the camera moves per second once a wall that
-- pushed it in is gone. It is pushed in at once.
local collision_return_speed = 3

--- The camera falls back to the first person view when it is closer than this to the eyes.
local min_distance = 10

--- How fast, in degrees per second, the character turns towards the way they move.
local turn_rate = 540

--- How far the aim trace reaches from the camera.
local aim_range = 32768

--- How far the camera can look up (negative) and down (positive), in degrees. It stops short
-- of the vertical so that the direction from the eyes to what the crosshair is on keeps a
-- well-defined yaw.
local min_pitch = -85
local max_pitch = 80

--- An aim steeper than this many degrees keeps the facing the character already has, since
-- its yaw would be meaningless.
local steep_aim_pitch = 85

--- Half the size of the box that is traced from the eyes to the camera.
local hull_mins = Vector(-4, -4, -4)
local hull_maxs = Vector(4, 4, 4)

--- What stops the camera: solid things except players and NPCs, so that the camera is not
-- pushed in by people walking behind the character.
local camera_mask = bit.band(MASK_SOLID, bit.bnot(CONTENTS_MONSTER))

local view = {}
local view_angles = Angle(0, 0, 0)
local camera_trace = {}
local aim_trace = {}
local zero_offset = Vector(0, 0, 0)

-- State of the camera and the character, kept on the plugin table so that it survives a reload
-- of this file.
ThirdPerson.camera_angles = ThirdPerson.camera_angles or Angle(0, 0, 0)
ThirdPerson.camera_offset = ThirdPerson.camera_offset or Vector(0, 0, 0)
ThirdPerson.facing_yaw = ThirdPerson.facing_yaw or 0
ThirdPerson.shoulder = ThirdPerson.shoulder or 1
ThirdPerson.blend = ThirdPerson.blend or 0
ThirdPerson.collision_fraction = ThirdPerson.collision_fraction or 1
ThirdPerson.camera_fov = ThirdPerson.camera_fov or 0
ThirdPerson.was_enabled = ThirdPerson.was_enabled or false
ThirdPerson.was_orbiting = ThirdPerson.was_orbiting or false
ThirdPerson.orbiting = ThirdPerson.orbiting or false
ThirdPerson.aiming = ThirdPerson.aiming or false
ThirdPerson.firing = ThirdPerson.firing or false

--- Reads the shoulder the camera starts over from the `thirdperson_shoulder` client setting.
-- @return [Number 1 for the right shoulder, -1 for the left one]
local function shoulder_setting()
  if ClientSettings and ClientSettings:get('thirdperson_shoulder', 'right') == 'left' then
    return -1
  end

  return 1
end

--- Reads how far behind the character the camera is while not aiming from the
-- `thirdperson_distance` client setting.
-- @return [Number distance in units, from 50 to 150]
local function distance_setting()
  if ClientSettings then
    return math.Clamp(
      tonumber(ClientSettings:get('thirdperson_distance', default_distance)) or default_distance,
      50,
      150
    )
  end

  return default_distance
end

--- Checks whether the camera orbits the character with angles of its own: while the third
-- person control is in effect, and while the player is playing an animation of the
-- Animations plugin with the view on, since the plugin locks the character in place and the
-- camera would otherwise jump to the way they face. Not in a vehicle, not while dead and not
-- while the player sees through another entity.
-- @param client [Player]
-- @return [Boolean]
local function is_orbiting(client)
  if ThirdPerson:is_controlling(client) then
    return true
  end

  if !ThirdPerson:is_enabled(client) or !client:get_nv('fl_animation') then
    return false
  end

  return client:Alive() and !client:InVehicle() and GetViewEntity() == client
end

--- Moves a value towards a target by a share of the distance that depends on the frame time,
-- so that it eases in at the same pace whatever the frame rate.
-- @param current [Number]
-- @param target [Number]
-- @param frame_time [Number seconds since the last frame]
-- @return [Number]
local function ease_towards(current, target, frame_time)
  return Lerp(1 - math.exp(-smooth_speed * frame_time), current, target)
end

--- Works out the view angles that make the shots of a player land on the crosshair: a trace is
-- run from the camera along its forward direction, and the angles point from the eyes of the
-- player at what it hits. When the hit is closer to the camera than the player is, which is
-- when something is between them, the camera angles are used instead.
-- The camera position is rebuilt from the offset the last CalcView left, turned with the
-- current camera angles.
-- @param client [Player]
-- @return [Angle]
function ThirdPerson:get_aim_angles(client)
  local angles = self.camera_angles
  local forward, right, up = angles:Forward(), angles:Right(), angles:Up()
  local offset = self.camera_offset
  local eye_pos = client:EyePos()
  local camera_pos = eye_pos + forward * offset.x + right * offset.y + up * offset.z

  aim_trace.start = camera_pos
  aim_trace.endpos = camera_pos + forward * aim_range
  aim_trace.filter = client
  aim_trace.mask = MASK_SHOT

  local hit_pos = util.TraceLine(aim_trace).HitPos

  if hit_pos:DistToSqr(camera_pos) <= eye_pos:DistToSqr(camera_pos) then
    return Angle(angles.p, angles.y, 0)
  end

  local aim = (hit_pos - eye_pos):Angle()

  aim.p = math.Clamp(math.NormalizeAngle(aim.p), -89, 89)
  aim.y = math.NormalizeAngle(aim.y)
  aim.r = 0

  -- Nearly vertical: the yaw of the direction means nothing, so the character keeps facing
  -- the way they do.
  if math.abs(aim.p) > steep_aim_pitch then
    aim.y = self.facing_yaw
  end

  return aim
end

--- Turns the camera with the mouse and decides where the character faces while the camera
-- orbits the character (see `is_orbiting`).
-- The engine turns the view angles of every command by the mouse, starting from the angles
-- the previous command was given. The camera therefore takes the difference between the view
-- angles of the command and the angles this handler set last time, which is the mouse
-- movement with the player's own sensitivity and acceleration, and anything else that has
-- turned the view, such as a server that has set the angles of the player.
-- While the control is in effect and the player aims or fires, the character faces what the
-- crosshair is on; otherwise it turns towards the way it is moved, relative to the camera, at
-- a limited rate and walks forward, and keeps its facing when it stops. During an animation
-- of the Animations plugin, which locks the character, the view angles simply follow the
-- camera.
-- While the camera does not orbit the command is left alone and the camera angles follow its
-- view angles, so that the camera does not jump when the orbit starts. When the orbit ends
-- with the player on foot, for example when the view is turned off, the view angles are set
-- to the camera angles so that the first person view looks where the camera did.
-- @param user_cmd [CUserCmd]
function ThirdPerson:CreateMove(user_cmd)
  local client = PLAYER

  if !IsValid(client) then return end

  local cur_time = RealTime()
  local delta = math.Clamp(cur_time - (self.last_move_time or cur_time), 0, 0.1)

  self.last_move_time = cur_time

  local controlling = self:is_controlling(client)
  local orbiting = controlling or is_orbiting(client)
  local angles = user_cmd:GetViewAngles()

  if !orbiting then
    if self.was_orbiting and client:Alive() and !client:InVehicle() and !client:get_nv('fl_animation') then
      angles = Angle(self.camera_angles.p, self.camera_angles.y, 0)

      user_cmd:SetViewAngles(angles)
    end

    self.camera_angles = Angle(angles.p, angles.y, 0)
    self.facing_yaw = angles.y
    self.was_orbiting = false
    self.orbiting = false
    self.last_view_angles = nil
    self.aiming = false
    self.firing = false

    return
  end

  local camera_angles = self.camera_angles
  local last_angles = self.last_view_angles

  if !self.was_orbiting or !last_angles then
    -- The view angles of this command already hold its mouse movement.
    camera_angles = Angle(
      math.Clamp(math.NormalizeAngle(angles.p), min_pitch, max_pitch),
      math.NormalizeAngle(angles.y),
      0
    )

    self.camera_angles = camera_angles
    self.facing_yaw = camera_angles.y
    self.was_orbiting = true
  else
    camera_angles.p = math.Clamp(camera_angles.p + math.AngleDifference(angles.p, last_angles.p), min_pitch, max_pitch)
    camera_angles.y = math.NormalizeAngle(camera_angles.y + math.AngleDifference(angles.y, last_angles.y))
    camera_angles.r = 0
  end

  self.orbiting = true

  local new_angles

  if !controlling then
    self.aiming = false
    self.firing = false

    new_angles = Angle(camera_angles.p, camera_angles.y, 0)
  else
    local aiming, firing = self:read_input(user_cmd:GetButtons(), client:GetActiveWeapon())

    self.aiming = aiming
    self.firing = firing

    if aiming or firing then
      new_angles = self:get_aim_angles(client)
      self.facing_yaw = new_angles.y
    else
      local forward_move = user_cmd:GetForwardMove()
      local side_move = user_cmd:GetSideMove()

      if forward_move != 0 or side_move != 0 then
        -- Positive side movement is to the right, positive yaw to the left.
        local wish_yaw = camera_angles.y + math.deg(math.atan2(-side_move, forward_move))

        self.facing_yaw = math.NormalizeAngle(math.ApproachAngle(self.facing_yaw, wish_yaw, turn_rate * delta))

        user_cmd:SetForwardMove(math.sqrt(forward_move * forward_move + side_move * side_move))
        user_cmd:SetSideMove(0)
      end

      new_angles = Angle(camera_angles.p, self.facing_yaw, 0)
    end
  end

  user_cmd:SetViewAngles(new_angles)

  self.last_view_angles = Angle(new_angles.p, new_angles.y, 0)
end

--- Places the camera while the third person view is on, and while it eases back into the first
-- person view after being turned off.
-- The camera orbits the eyes of the character over a shoulder, with the camera angles while
-- it orbits on its own (see `is_orbiting`) and the view angles otherwise; while aiming it moves
-- in closer and narrows the field of view. Every offset eases towards its target, and the
-- view eases between the first and the third person over 0.15 seconds. A box is traced from
-- the eyes to the camera so that it stops in front of walls, and the view becomes first person
-- when the camera ends up too close to the eyes. Picks up the shoulder from the
-- `thirdperson_shoulder` client setting whenever the view is turned on.
-- @param client [Player]
-- @param pos [Vector]
-- @param angles [Angle]
-- @param fov [Number]
-- @return [Map view table, or nil while the first person view is shown or the player looks
--   through another entity]
function ThirdPerson:CalcView(client, pos, angles, fov)
  local enabled = self:is_enabled(client)

  if enabled and !self.was_enabled then
    self.shoulder = shoulder_setting()
  end

  self.was_enabled = enabled

  if GetViewEntity() != client then return end

  local frame_time = FrameTime()
  local blend = math.Approach(self.blend, enabled and 1 or 0, frame_time / blend_duration)

  self.blend = blend

  -- This also keeps the view from glitching on autorefresh.
  if blend <= 0 then
    self.camera_offset = zero_offset

    return
  end

  local aiming = self.orbiting and self.aiming
  local camera_angles = self.orbiting and self.camera_angles or angles
  local target_distance = aiming and aim_distance or distance_setting()
  local target_side = (aiming and aim_side or idle_side) * self.shoulder
  local target_up = aiming and aim_up or idle_up
  local target_fov = aiming and aim_fov or 0

  self.camera_distance = ease_towards(self.camera_distance or target_distance, target_distance, frame_time)
  self.camera_side = ease_towards(self.camera_side or target_side, target_side, frame_time)
  self.camera_up = ease_towards(self.camera_up or target_up, target_up, frame_time)
  self.camera_fov = ease_towards(self.camera_fov, target_fov, frame_time)

  local eased = blend * blend * (3 - 2 * blend)
  local forward, right, up = camera_angles:Forward(), camera_angles:Right(), camera_angles:Up()
  local wanted =
    pos - forward * (self.camera_distance * eased) + right * (self.camera_side * eased) + up * (self.camera_up * eased)

  camera_trace.start = pos
  camera_trace.endpos = wanted
  camera_trace.mins = hull_mins
  camera_trace.maxs = hull_maxs
  camera_trace.filter = client
  camera_trace.mask = camera_mask

  local trace = util.TraceHull(camera_trace)
  local fraction = trace.StartSolid and 0 or trace.Fraction
  local collision = self.collision_fraction

  if fraction < collision then
    collision = fraction
  else
    collision = math.Approach(collision, fraction, frame_time * collision_return_speed)
  end

  self.collision_fraction = collision

  local origin = pos + (wanted - pos) * collision

  view_angles:Set(camera_angles)
  view_angles.r = 0

  view.angles = view_angles
  view.fov = fov + self.camera_fov * eased

  if origin:DistToSqr(pos) < min_distance * min_distance then
    view.origin = pos
    view.drawviewer = false

    self.camera_offset = zero_offset
  else
    local offset = origin - pos

    view.origin = origin
    view.drawviewer = true

    self.camera_offset = Vector(offset:Dot(forward), offset:Dot(right), offset:Dot(up))
  end

  return view
end

--- Hides the crosshair while the third person control is in effect and the local player is
-- neither aiming nor firing.
-- @return [Boolean false to hide the crosshair, nil otherwise]
function ThirdPerson:ShouldHUDPaintCrosshair()
  if self:is_controlling(PLAYER) and !self.aiming and !self.firing then
    return false
  end
end

--- Moves the camera to the shoulder a new value of the `thirdperson_shoulder` client setting
-- names.
-- @param value [String 'right' or 'left']
local function apply_shoulder(value)
  ThirdPerson.shoulder = value == 'left' and -1 or 1
end

--- Registers the client settings of the camera with the Settings plugin:
-- 'thirdperson_shoulder', the shoulder the camera is over when the view is turned on, and
-- 'thirdperson_distance', how far behind the character it is while not aiming. Only called
-- when the Settings plugin is loaded.
function ThirdPerson:RegisterClientSettings()
  ClientSettings:register_setting('thirdperson_shoulder', {
    type = 'choice',
    default = 'right',
    choices = {
      { value = 'right', name = 'settings.thirdperson.shoulder.right' },
      { value = 'left', name = 'settings.thirdperson.shoulder.left' }
    },
    category = 'settings.categories.gameplay',
    name = 'settings.thirdperson.shoulder.name',
    description = 'settings.thirdperson.shoulder.desc',
    on_change = apply_shoulder
  })

  ClientSettings:register_setting('thirdperson_distance', {
    type = 'number',
    default = default_distance,
    min = 50,
    max = 150,
    decimals = 0,
    category = 'settings.categories.gameplay',
    name = 'settings.thirdperson.distance.name',
    description = 'settings.thirdperson.distance.desc'
  })
end

--- Moves the camera over the other shoulder. Run by the `fl_switch_shoulder` console command.
local function switch_shoulder()
  ThirdPerson.shoulder = -(ThirdPerson.shoulder or 1)
end

concommand.Add('fl_switch_shoulder', switch_shoulder)

Flux.Binds:add_bind('ToggleThirdPerson', 'fl_third_person', KEY_P)
Flux.Binds:add_bind('SwitchShoulder', 'fl_switch_shoulder', KEY_B)
