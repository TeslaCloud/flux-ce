--- Client side of the Third Person plugin: the camera, which orbits the character with
-- angles of its own, the view angles of the local player, which follow what the middle of the
-- screen shows, the crosshair and the weapon state indicator, the client settings of the
-- camera and the key binds.
--
-- The camera is turned by the mouse in CreateMove, which keeps the camera angles itself and
-- sends, as the view angles of the command, the direction from the eyes of the player to what
-- the camera looks at. Everything that follows the eyes of the player, from shots to spawned
-- props, therefore goes where the middle of the screen is, while the model of the character
-- is turned on its own by the shared `UpdateAnimation` handler.

--- Seconds the camera takes to move between the first and the third person view.
local blend_duration = 0.15

--- Offsets of the camera from the eyes of the character, in units, while not aiming: it is
-- straight behind them and this far above. How far back it is comes from the
-- `third_person_distance` client setting.
local idle_up = 12
local default_distance = 90

--- Offsets of the camera while aiming: how far back, to the side (towards the shoulder) and
-- above it is, and how much the field of view is narrowed, in degrees.
local aim_distance = 45
local aim_side = 22
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

--- How far the aim trace reaches from the camera.
local aim_range = 32_768

--- How far the camera can look up (negative) and down (positive), in degrees. It stops short
-- of the vertical so that the direction from the eyes to what the camera looks at keeps a
-- well-defined yaw.
local min_pitch = -85
local max_pitch = 80

--- An aim steeper than this many degrees takes its yaw from the camera, since the yaw of the
-- direction from the eyes would be meaningless.
local steep_aim_pitch = 85

--- Half the size of the box that is traced from the eyes to the camera.
local hull_mins = Vector(-4, -4, -4)
local hull_maxs = Vector(4, 4, 4)

--- What stops the camera: solid things except players and NPCs, so that the camera is not
-- pushed in by people walking behind the character.
local camera_mask = MASK_SOLID & ~CONTENTS_MONSTER

--- A next fire further away than this many seconds is the Raise Weapon plugin keeping a
-- lowered weapon from firing.
local fire_blocked_after = 3600

--- How long, in seconds, the label that tells that the weapon has been raised or lowered is
-- shown, and over how many of the last of them it fades out.
local label_duration = 1.5
local label_fade = 0.5

--- Colors of the weapon state feedback: the crosshair while the weapon is being raised and
-- cannot fire yet, the dot shown in the middle of the screen while the crosshair is hidden,
-- the ring that shows how long the weapon stays raised, and the label.
local color_raising = Color(230, 170, 90)
local color_dot = Color(255, 255, 255, 70)
local color_ring = Color(255, 255, 255, 60)
local color_label = Color(255, 255, 255)
local color_label_outline = Color(0, 0, 0)

local view = {}
local view_angles = Angle(0, 0, 0)
local camera_trace = {}
local aim_trace = {}
local zero_offset = Vector(0, 0, 0)

ThirdPerson.camera_angles = ThirdPerson.camera_angles or Angle(0, 0, 0)
ThirdPerson.camera_offset = ThirdPerson.camera_offset or Vector(0, 0, 0)
ThirdPerson.shoulder = ThirdPerson.shoulder or 1
ThirdPerson.blend = ThirdPerson.blend or 0
ThirdPerson.collision_fraction = ThirdPerson.collision_fraction or 1
ThirdPerson.camera_fov = ThirdPerson.camera_fov or 0
ThirdPerson.was_enabled = ThirdPerson.was_enabled or false
ThirdPerson.was_orbiting = ThirdPerson.was_orbiting or false
ThirdPerson.orbiting = ThirdPerson.orbiting or false
ThirdPerson.aiming = ThirdPerson.aiming or false
ThirdPerson.firing = ThirdPerson.firing or false

local function shoulder_setting()
  return ClientSettings:get('third_person_shoulder', 'right') == 'left' ? -1 : 1
end

local function distance_setting()
  local distance = tonumber(ClientSettings:get('third_person_distance', default_distance))

  return math.Clamp(distance or default_distance, 50, 150)
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

--- Works out the view angles that point the eyes of a player at what the middle of the screen
-- shows: a trace is run from the camera along its forward direction, and the angles point from
-- the eyes of the player at what it hits. When the hit is closer to the camera than the player
-- is, which is when something is between them, the camera angles are used instead.
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

  if math.abs(aim.p) > steep_aim_pitch then
    aim.y = angles.y
  end

  return aim
end

--- Turns the camera with the mouse and points the eyes of the local player at what the middle
-- of the screen shows while the camera orbits the character (see `is_orbiting`).
-- The engine turns the view angles of every command by the mouse, starting from the angles
-- the previous command was given. The camera therefore takes the difference between the view
-- angles of the command and the angles it saw or set last time, which is the mouse movement
-- with the player's own sensitivity and acceleration, and anything else that has turned the
-- view, such as a server that has set the angles of the player.
-- The view angles are only set, and the aim and fire input only read, in the commands that
-- are sent to the server. The commands that the engine builds between them to sample the
-- mouse every frame (whose command number is 0) only turn the camera, so that nothing depends
-- on whether the engine keeps what is done to them.
-- While the control is in effect the view angles point from the eyes at the hit of a trace
-- from the camera (see `ThirdPerson:get_aim_angles`). During an animation of the Animations
-- plugin, which locks the character, they are the camera angles.
-- While the camera does not orbit the command is left alone and the camera angles follow its
-- view angles, so that the camera does not jump when the orbit starts. When the orbit ends
-- with the player on foot, for example when the view is turned off, the view angles are set
-- to the camera angles so that the first person view looks where the camera did.
-- @param user_cmd [CUserCmd]
function ThirdPerson:CreateMove(user_cmd)
  local client = PLAYER

  if !IsValid(client) then return end

  local controlling = self:is_controlling(client)
  local orbiting = controlling or is_orbiting(client)
  local angles = user_cmd:GetViewAngles()

  if !orbiting then
    if self.was_orbiting and client:Alive() and !client:InVehicle() and !client:get_nv('fl_animation') then
      angles = Angle(self.camera_angles.p, self.camera_angles.y, 0)

      user_cmd:SetViewAngles(angles)
    end

    self.camera_angles = Angle(angles.p, angles.y, 0)
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
    camera_angles = Angle(
      math.Clamp(math.NormalizeAngle(angles.p), min_pitch, max_pitch),
      math.NormalizeAngle(angles.y),
      0
    )

    self.camera_angles = camera_angles
    self.was_orbiting = true
  else
    camera_angles.p = math.Clamp(camera_angles.p + math.AngleDifference(angles.p, last_angles.p), min_pitch, max_pitch)
    camera_angles.y = math.NormalizeAngle(camera_angles.y + math.AngleDifference(angles.y, last_angles.y))
    camera_angles.r = 0
  end

  self.orbiting = true

  if user_cmd:CommandNumber() == 0 then
    self.last_view_angles = Angle(angles.p, angles.y, 0)

    return
  end

  local new_angles

  if controlling then
    self.aiming, self.firing = self:read_input(user_cmd:GetButtons(), client:GetActiveWeapon())

    new_angles = self:get_aim_angles(client)
  else
    self.aiming = false
    self.firing = false

    new_angles = Angle(camera_angles.p, camera_angles.y, 0)
  end

  user_cmd:SetViewAngles(new_angles)

  self.last_view_angles = Angle(new_angles.p, new_angles.y, 0)
end

--- Places the camera while the third person view is on, and while it eases back into the first
-- person view after being turned off.
-- The camera orbits the eyes of the character from straight behind them, with the camera angles
-- while it orbits on its own (see `is_orbiting`) and the view angles otherwise. While aiming it
-- moves in over a shoulder and narrows the field of view. Every offset eases towards its
-- target, and the view eases between the first and the third person over 0.15 seconds. A box
-- is traced from the eyes to the camera so that it stops in front of walls, and the view
-- becomes first person when the camera ends up too close to the eyes. Picks up the shoulder
-- from the `third_person_shoulder` client setting whenever the view is turned on.
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
  local blend = math.Approach(self.blend, enabled ? 1 : 0, frame_time / blend_duration)

  self.blend = blend

  if blend <= 0 then
    self.camera_offset = zero_offset

    return
  end

  local aiming = self.orbiting and self.aiming
  local camera_angles = self.orbiting and self.camera_angles or angles
  local target_distance = aiming and aim_distance or distance_setting()
  local target_side = aiming and aim_side * self.shoulder or 0
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
  local fraction = trace.StartSolid ? 0 : trace.Fraction
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

--- Works out the raised state of the local player's weapon for the weapon state feedback.
-- @param client [Player the local player]
-- @return [String 'raised' when the server has raised the weapon and it can fire, 'raising'
--   while the player aims or fires or the weapon is to stay raised but it cannot fire yet,
--   'lowered' otherwise; nil without the Raise Weapon plugin, while its `raise_gun_enabled`
--   config is off, without a weapon and for a weapon whose state is fixed]
local function weapon_state(client)
  if !RaiseGun or !Config.get('raise_gun_enabled', true) then return end

  local weapon = client:GetActiveWeapon()

  if !IsValid(weapon) or RaiseGun:get_fixed_state(weapon) != nil then return end

  local cur_time = CurTime()

  if client:GetDTBool(BOOL_WEAPON_RAISED) and weapon:GetNextPrimaryFire() < cur_time + fire_blocked_after then
    return 'raised'
  end

  if ThirdPerson.aiming or ThirdPerson.firing or cur_time < (ThirdPerson.local_raise_until or 0) then
    return 'raising'
  end

  return 'lowered'
end

--- Hides the crosshair while the third person control is in effect and the model of the local
-- player does not face their aim, that is while their weapon is lowered and they neither aim
-- nor fire. The tools that are always raised, such as the physgun and the tool gun, keep it.
-- A faint dot is drawn in its place by the `HUDPaint` handler. Nothing is answered while that
-- handler asks the other plugins whether they hide the crosshair.
-- @return [Boolean false to hide the crosshair, nil otherwise]
function ThirdPerson:ShouldHUDPaintCrosshair()
  if self.asking_crosshair then return end

  if self:is_controlling(PLAYER) and !self:faces_aim(PLAYER) then
    return false
  end
end

--- Tints the crosshair while the local player's weapon is being raised in third person and
-- cannot fire yet.
-- @param _trace [Map trace result of the local player's aim]
-- @param _distance [Number distance from the local player to the trace hit position]
-- @return [Color the tint, or nil to leave the color alone]
function ThirdPerson:GetCrosshairColor(_trace, _distance)
  if self:is_controlling(PLAYER) and weapon_state(PLAYER) == 'raising' then
    return color_raising
  end
end

--- Draws the weapon state feedback of third person control: a faint dot in the middle of the
-- screen while the crosshair is hidden, so that the player sees what they would use or spawn
-- something at, unless another plugin hides the crosshair as well, during a cinematic or
-- while running for example; a ring around the crosshair that runs down while the weapon
-- stays raised after the player has stopped aiming and firing; and a label under it for a
-- moment after the weapon has been raised or lowered.
function ThirdPerson:HUDPaint()
  local client = PLAYER

  if !IsValid(client) or !self:is_controlling(client) or !client:Alive() then
    self.last_weapon_state = nil
    self.weapon_label = nil

    return
  end

  --- Flux's `ShouldHUDPaint` hook, asked here before the weapon state feedback is drawn.
  -- @return [Boolean Return false to hide the HUD and the feedback with it]
  if hook.Run('ShouldHUDPaint') == false then return end

  local state = weapon_state(client)
  local now = RealTime()
  local last_state = self.last_weapon_state

  if state != last_state then
    if last_state and (state == 'raised' or state == 'lowered') then
      self.weapon_label = state
      self.weapon_label_time = now
    end

    self.last_weapon_state = state
  end

  local gox, goy = Flux.global_ui_offset()
  local center_x, center_y = gox + ScrW() * 0.5, goy + ScrH() * 0.5

  if !self:faces_aim(client) then
    self.asking_crosshair = true

    local crosshair_hidden = hook.Run('ShouldHUDPaintCrosshair') == false

    self.asking_crosshair = nil

    if !crosshair_hidden then
      local size = math.scale(2)

      draw.RoundedBox(0, center_x - size * 0.5, center_y - size * 0.5, size, size, color_dot)
    end
  elseif state == 'raised' and !self.aiming and !self.firing then
    local remaining = ((self.local_raise_until or 0) - CurTime()) / self.raise_grace

    if remaining > 0 then
      draw.NoTexture()
      surface.SetDrawColor(color_ring)
      surface.draw_circle_outline_partial(
        math.Clamp(remaining * 100, 0, 100),
        center_x,
        center_y,
        math.scale(16),
        math.scale(2),
        48
      )
    end
  end

  local label = self.weapon_label

  if label then
    local age = now - (self.weapon_label_time or now)

    if age >= label_duration then
      self.weapon_label = nil
    else
      local alpha = 255 * math.Clamp((label_duration - age) / label_fade, 0, 1)

      draw.SimpleTextOutlined(
        t(label == 'raised' ? 'ui.third_person.weapon_raised' : 'ui.third_person.weapon_lowered'),
        Theme.get_font('text_small'),
        center_x,
        center_y + math.scale(24),
        color_label:alpha(alpha),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_TOP,
        1,
        color_label_outline:alpha(alpha * 0.6)
      )
    end
  end
end

local function apply_shoulder(value)
  ThirdPerson.shoulder = value == 'left' ? -1 : 1
end

--- Registers the client settings of the camera: 'third_person_shoulder', the shoulder the
-- camera aims over when the view is turned on, and 'third_person_distance', how far behind the
-- character it is while not aiming.
function ThirdPerson:RegisterClientSettings()
  ClientSettings:register_setting('third_person_shoulder', {
    type = 'choice',
    default = 'right',
    choices = {
      { value = 'right', name = 'settings.third_person.shoulder.right' },
      { value = 'left', name = 'settings.third_person.shoulder.left' }
    },
    category = 'settings.categories.gameplay',
    name = 'settings.third_person.shoulder.name',
    description = 'settings.third_person.shoulder.desc',
    on_change = apply_shoulder
  })

  ClientSettings:register_setting('third_person_distance', {
    type = 'number',
    default = default_distance,
    min = 50,
    max = 150,
    decimals = 0,
    category = 'settings.categories.gameplay',
    name = 'settings.third_person.distance.name',
    description = 'settings.third_person.distance.desc'
  })
end

local function switch_shoulder()
  ThirdPerson.shoulder = -(ThirdPerson.shoulder or 1)
end

concommand.Add('fl_switch_shoulder', switch_shoulder)

Flux.Binds:add_bind('ToggleThirdPerson', 'fl_third_person', KEY_P)
Flux.Binds:add_bind('SwitchShoulder', 'fl_switch_shoulder', KEY_B)
