--- Client side of the Screen Effects plugin: the list of effects, the checks that decide
-- whether an effect is applied, the state that is advanced every frame and the drawing of the
-- screen passes.
--
-- `ScreenEffects.effects` maps the ID of an effect to its `config` key, the IDs of its
-- `setting` and `strength` settings and the `max_strength` of the latter in percent.
-- `ScreenEffects.effect_order` lists the IDs in the order of the settings menu.
--
-- `ScreenEffects.screen` holds what the screen passes draw: `saturation` (1 leaves the colors
-- alone, 0 is gray), `brightness` (0 leaves it alone), `contrast` (1 leaves it alone),
-- `motion_blur` (0 for none to 1 for the heaviest), `refraction` (how far the picture is
-- distorted, 0 for none) and `blur` (how far it is blurred, 0 for none). `ScreenEffects.view`
-- holds the `pitch`, `yaw` and `roll` that are added to the view angles, in degrees.
--
-- `ScreenEffects.defaults` holds the numbers the effects are built from:
--
-- * `drain_speed`: how much of the low health effect fades in or out in a second.
-- * `blur_health`: the fraction of health below which the motion blur starts.
-- * `motion_blur`: the motion blur of a player with no health left.
-- * `submerge_speed`: how much of the underwater effect fades in or out in a second.
-- * `refraction` and `blur`: the distortion and the blur of the underwater effect.
-- * `heartbeat_health`: the fraction of health below which the heartbeat is heard.
-- * `heartbeat_slow` and `heartbeat_fast`: the seconds between two beats at that health and
--   with no health left.
-- * `heartbeat_quiet` and `heartbeat_loud`: the volume at these two ends.
-- * `heartbeat_pitch`: the pitch of the beat with no health left, in percent.
-- * `heartbeat_length`: how many seconds of the heartbeat sound make up one beat at the normal
--   pitch. The sound is a loop of a single beat, so every beat is cut off after that time.
-- * `bob_min_speed`: the speed below which the player counts as standing still.
-- * `bob_rate_min` and `bob_rate_max`: how fast the sway of the headbob cycles at a standstill
--   and at the run speed, in radians per second.
-- * `bob_pitch`, `bob_yaw` and `bob_roll`: the sway of the headbob at the run speed, in
--   degrees.
-- * `bob_lean`: how far the view leans into strafing at the run speed, in degrees.
-- * `bob_smoothing`: how quickly the headbob follows a change of movement.
-- * `fall_min_speed` and `fall_max_speed`: the landing speeds at which the fall shake starts
--   and reaches its full strength.
-- * `fall_pitch_min` and `fall_pitch_max`: how far the view dips at these two speeds, in
--   degrees.
-- * `fall_roll`: how far the view wobbles sideways at the highest speed, in degrees.
-- * `fall_duration_min` and `fall_duration_max`: how long the shake lasts, in seconds.

local stored = {
  low_health = {
    config = 'allow_low_health_effect',
    setting = 'low_health_effect',
    strength = 'low_health_effect_strength',
    max_strength = 100
  },
  heartbeat = {
    config = 'allow_heartbeat_effect',
    setting = 'heartbeat_effect',
    strength = 'heartbeat_effect_strength',
    max_strength = 100
  },
  underwater = {
    config = 'allow_underwater_effect',
    setting = 'underwater_effect',
    strength = 'underwater_effect_strength',
    max_strength = 200
  },
  headbob = {
    config = 'allow_headbob_effect',
    setting = 'headbob_effect',
    strength = 'headbob_effect_strength',
    max_strength = 300
  }
}
local effect_order = { 'low_health', 'heartbeat', 'underwater', 'headbob' }
local defaults = ScreenEffects.defaults or {
  drain_speed = 1.5,
  blur_health = 0.75,
  motion_blur = 0.6,
  submerge_speed = 4,
  refraction = 0.1,
  blur = 2.5,
  heartbeat_health = 0.6,
  heartbeat_slow = 1.5,
  heartbeat_fast = 0.6,
  heartbeat_quiet = 0.2,
  heartbeat_loud = 0.75,
  heartbeat_pitch = 115,
  heartbeat_length = 0.68,
  bob_min_speed = 10,
  bob_rate_min = 5.5,
  bob_rate_max = 10.5,
  bob_pitch = 0.4,
  bob_yaw = 0.3,
  bob_roll = 0.5,
  bob_lean = 0.8,
  bob_smoothing = 8,
  fall_min_speed = 220,
  fall_max_speed = 800,
  fall_pitch_min = 1.5,
  fall_pitch_max = 8,
  fall_roll = 1.5,
  fall_duration_min = 0.3,
  fall_duration_max = 0.7
}
local screen = ScreenEffects.screen or {
  saturation = 1,
  brightness = 0,
  contrast = 1,
  motion_blur = 0,
  refraction = 0,
  blur = 0
}
local view = ScreenEffects.view or { pitch = 0, yaw = 0, roll = 0 }
local levels = { damage = 0, submerged = 0 }
local bob = { phase = 0, speed = 0, pitch = 0, yaw = 0, roll = 0, lean = 0 }
local bob_info = { speed = 0, pitch = 0, yaw = 0, roll = 0, lean = 0 }
local shake = { pitch = 0, roll = 0, duration = 0, elapsed = 0 }
local heartbeat_info = { interval = 0, volume = 0, pitch = 100 }
local fall_speed = 0
local color_modify = {
  ['$pp_colour_addr'] = 0,
  ['$pp_colour_addg'] = 0,
  ['$pp_colour_addb'] = 0,
  ['$pp_colour_brightness'] = 0,
  ['$pp_colour_contrast'] = 1,
  ['$pp_colour_colour'] = 1,
  ['$pp_colour_mulr'] = 0,
  ['$pp_colour_mulg'] = 0,
  ['$pp_colour_mulb'] = 0
}
local heartbeat_path = 'player/heartbeat1.wav'
local refract_material = Material('models/props_c17/fisheyelens')
local blur_material = Material('pp/blurscreen')
local blur_passes = 3

ScreenEffects.effects = stored
ScreenEffects.effect_order = effect_order
ScreenEffects.defaults = defaults
ScreenEffects.screen = screen
ScreenEffects.view = view

--- Reads a number that a hook handler may have replaced with something else.
-- @param value [Any value to read]
-- @param default [Number returned if the value is not a number]
-- @return [Number]
local function to_number(value, default)
  return tonumber(value) or default
end

--- Distorts the picture through the lens material.
-- @param amount [Number how far the picture is distorted]
local function draw_refraction(amount)
  if refract_material:IsError() then return end

  render.UpdateScreenEffectTexture()

  refract_material:SetFloat('$envmap', 0)
  refract_material:SetFloat('$envmaptint', 0)
  refract_material:SetFloat('$refractamount', amount)
  refract_material:SetInt('$ignorez', 1)

  render.SetMaterial(refract_material)
  render.DrawScreenQuad()
end

--- Blurs the picture in a few passes of the screen blur material, and puts the blur amount
-- of that material back afterwards, as the material is shared with the interface.
-- @param amount [Number how far the picture is blurred]
local function draw_blur(amount)
  local previous = blur_material:GetFloat('$blur')

  for i = 1, blur_passes do
    blur_material:SetFloat('$blur', amount * i / blur_passes)
    blur_material:Recompute()

    render.UpdateScreenEffectTexture()
    render.SetMaterial(blur_material)
    render.DrawScreenQuad()
  end

  if previous then
    blur_material:SetFloat('$blur', previous)
    blur_material:Recompute()
  end
end

--- Checks whether the server allows an effect.
-- @param id [String effect ID: 'low_health', 'heartbeat', 'underwater' or 'headbob']
-- @return [Boolean true if the config of the effect is on, false if it is off or there is no
--   such effect]
function ScreenEffects:is_effect_allowed(id)
  local effect = stored[id]

  if !effect then
    return false
  end

  return Config.get(effect.config, true) != false
end

--- Checks whether an effect is applied to the local player: the server allows it, the player
-- has not turned it off and the ShouldApplyScreenEffect hook does not suppress it.
-- @param id [String effect ID: 'low_health', 'heartbeat', 'underwater' or 'headbob']
-- @return [Boolean]
function ScreenEffects:is_effect_enabled(id)
  local effect = stored[id]

  if !self:is_effect_allowed(id) then
    return false
  end

  if ClientSettings and ClientSettings:get(effect.setting, true) == false then
    return false
  end

  --- Asks whether one of the effects of the Screen Effects plugin should be applied to the
  -- local player. Called on the client for an effect that the server allows and the player
  -- has turned on, each time the plugin is about to apply it; that is up to once a frame per
  -- effect while the player is in the game with a character.
  -- @param id [String effect ID: 'low_health', 'heartbeat', 'underwater' or 'headbob']
  -- @return [Boolean Return false to suppress the effect; return nothing to let the other
  --   handlers decide]
  return hook.Run('ShouldApplyScreenEffect', id) != false
end

--- Returns the strength the local player has set for an effect.
-- @param id [String effect ID: 'low_health', 'heartbeat', 'underwater' or 'headbob']
-- @return [Number multiplier of the effect, 1 being the default; always 1 without the
--   Settings plugin, 0 if there is no such effect]
function ScreenEffects:get_effect_strength(id)
  local effect = stored[id]

  if !effect then
    return 0
  end

  if !ClientSettings then
    return 1
  end

  return to_number(ClientSettings:get(effect.strength, 100), 100) / 100
end

--- Checks whether screen effects make sense right now: the local player has been initialized,
-- has a character loaded if the Characters plugin is there, and neither the intro nor the main
-- menu is open.
-- @return [Boolean]
function ScreenEffects:effects_active()
  local client = PLAYER

  if !IsValid(client) or !client:has_initialized() or IsValid(Flux.intro_panel) then
    return false
  end

  if client.is_character_loaded and !client:is_character_loaded() then
    return false
  end

  return true
end

--- Returns how much of their health the local player has left.
-- @return [Number 1 at full health or above, 0 with no health left or dead]
function ScreenEffects:get_health_fraction()
  local client = PLAYER

  if !client:Alive() then
    return 0
  end

  return math.Clamp(client:Health() / math.max(client:GetMaxHealth(), 1), 0, 1)
end

--- Puts everything back to where nothing is drawn, nothing is added to the view and no
-- heartbeat is heard. Called every frame while the effects are not active.
function ScreenEffects:reset_effects()
  levels.damage = 0
  levels.submerged = 0

  screen.saturation = 1
  screen.brightness = 0
  screen.contrast = 1
  screen.motion_blur = 0
  screen.refraction = 0
  screen.blur = 0

  view.pitch = 0
  view.yaw = 0
  view.roll = 0

  bob.speed = 0
  bob.pitch = 0
  bob.yaw = 0
  bob.roll = 0
  bob.lean = 0

  shake.duration = 0
  fall_speed = 0

  self:stop_heartbeat()
end

--- Works out what the screen passes draw this frame: fades the low health and the underwater
-- effect towards where they should be, writes their values to `ScreenEffects.screen` and runs
-- the AdjustScreenEffects hook.
-- @param frame_time [Number seconds since the last frame]
function ScreenEffects:update_screen(frame_time)
  local client = PLAYER
  local damage = 0
  local submerged = 0

  if self:is_effect_enabled('low_health') then
    damage = (1 - self:get_health_fraction()) * self:get_effect_strength('low_health')
  end

  if client:WaterLevel() >= 3 and GetViewEntity() == client and self:is_effect_enabled('underwater') then
    submerged = self:get_effect_strength('underwater')
  end

  levels.damage = math.Approach(levels.damage, damage, frame_time * defaults.drain_speed)
  levels.submerged = math.Approach(levels.submerged, submerged, frame_time * defaults.submerge_speed)

  local blur_health = math.Clamp(defaults.blur_health, 0.01, 1)

  screen.saturation = math.max(1 - levels.damage, 0)
  screen.brightness = 0
  screen.contrast = 1
  screen.motion_blur = math.Clamp((levels.damage - (1 - blur_health)) / blur_health, 0, 1) * defaults.motion_blur
  screen.refraction = levels.submerged * defaults.refraction
  screen.blur = levels.submerged * defaults.blur

  --- Lets plugins change what the screen passes of the Screen Effects plugin draw. Called on
  -- the client every frame while the local player is in the game with a character, after the
  -- low health and the underwater effect have written their values, and also when these
  -- effects are turned off, in which case the values are neutral. Change the fields in place;
  -- do not return anything from the handler, or the plugins after it are not asked.
  -- @param screen [Map values of the passes: saturation (Number, 1 leaves the colors alone and
  --   0 is gray), brightness (Number, 0 leaves it alone), contrast (Number, 1 leaves it alone),
  --   motion_blur (Number 0 to 1, 0 for none), refraction (Number how far the picture is
  --   distorted, 0 for none; the underwater effect uses 0.1) and blur (Number how far the
  --   picture is blurred, 0 for none; the underwater effect uses 2.5)]
  hook.Run('AdjustScreenEffects', screen)
end

--- Draws the screen passes from the values in `ScreenEffects.screen`: the distortion, the
-- blur, the motion blur and the color pass, each of them only if it would change the picture.
function ScreenEffects:draw_screen()
  local refraction = to_number(screen.refraction, 0)
  local blur = to_number(screen.blur, 0)
  local motion_blur = math.Clamp(to_number(screen.motion_blur, 0), 0, 1)
  local saturation = to_number(screen.saturation, 1)
  local brightness = to_number(screen.brightness, 0)
  local contrast = to_number(screen.contrast, 1)

  if refraction > 0 then
    draw_refraction(refraction)
  end

  if blur > 0 then
    draw_blur(blur)
  end

  if motion_blur > 0.01 then
    DrawMotionBlur(math.max(1 - motion_blur, 0.1), 1, 0)
  end

  if saturation != 1 or brightness != 0 or contrast != 1 then
    color_modify['$pp_colour_colour'] = saturation
    color_modify['$pp_colour_brightness'] = brightness
    color_modify['$pp_colour_contrast'] = contrast

    DrawColorModify(color_modify)
  end
end

--- Plays the next beat of the heartbeat when it is due, or stops the heartbeat when the local
-- player is dead, has enough health or the effect is not applied. The lower the health, the
-- sooner the next beat follows and the louder it is. The sound of the heartbeat is a loop of
-- a single beat that would repeat at its own pace, so every beat starts the sound over and
-- the sound is cut off once that beat has been heard.
function ScreenEffects:update_heartbeat()
  local client = PLAYER
  local fraction = self:get_health_fraction()
  local threshold = defaults.heartbeat_health

  if !client:Alive() or fraction >= threshold or !self:is_effect_enabled('heartbeat') then
    self:stop_heartbeat()

    return
  end

  local cur_time = CurTime()

  if self.heartbeat_end and cur_time >= self.heartbeat_end then
    self.heartbeat_end = nil
    self.heartbeat:Stop()
  end

  if self.next_heartbeat and cur_time < self.next_heartbeat then return end

  local danger = 1 - fraction / threshold
  local info = heartbeat_info

  info.interval = Lerp(danger, defaults.heartbeat_slow, defaults.heartbeat_fast)
  info.volume = Lerp(danger, defaults.heartbeat_quiet, defaults.heartbeat_loud) * self:get_effect_strength('heartbeat')
  info.pitch = Lerp(danger, 100, defaults.heartbeat_pitch)

  --- Lets plugins change the next beat of the low health heartbeat. Called on the client right
  -- before every beat, which is not every frame. Change the fields in place; do not return
  -- anything from the handler, or the plugins after it are not asked.
  -- @param info [Map the beat: interval (Number seconds until the beat after this one, at
  --   least 0.1), volume (Number 0 to 1, 0 skips this beat) and pitch (Number percent, 100
  --   being the normal pitch)]
  -- @param fraction [Number how much of their health the local player has left, 0 to 1]
  hook.Run('AdjustHeartbeat', info, fraction)

  self.next_heartbeat = cur_time + math.max(to_number(info.interval, defaults.heartbeat_slow), 0.1)

  local volume = math.Clamp(to_number(info.volume, 0), 0, 1)

  if volume <= 0 then return end

  local pitch = math.Clamp(to_number(info.pitch, 100), 1, 255)

  if !self.heartbeat or self.heartbeat_owner != client then
    if self.heartbeat then
      self.heartbeat:Stop()
    end

    self.heartbeat = CreateSound(client, heartbeat_path)
    self.heartbeat_owner = client
  end

  self.heartbeat:Stop()
  self.heartbeat:PlayEx(volume, pitch)
  self.heartbeat_end = cur_time + to_number(defaults.heartbeat_length, 0.68) * 100 / pitch
end

--- Stops the heartbeat if it has been playing.
function ScreenEffects:stop_heartbeat()
  if !self.next_heartbeat then return end

  self.next_heartbeat = nil
  self.heartbeat_end = nil

  if self.heartbeat then
    self.heartbeat:Stop()
  end
end

--- Starts the shake of the view that follows a landing. Does nothing if the local player
-- came down slower than `ScreenEffects.defaults.fall_min_speed`.
-- @param speed [Number downward speed right before the landing, in units per second]
function ScreenEffects:start_fall_shake(speed)
  local min_speed = defaults.fall_min_speed

  if speed < min_speed then return end

  local intensity = math.Clamp((speed - min_speed) / math.max(defaults.fall_max_speed - min_speed, 1), 0, 1)
  local strength = self:get_effect_strength('headbob')
  local side = math.random(2) == 1 and 1 or -1
  local info = {
    pitch = Lerp(intensity, defaults.fall_pitch_min, defaults.fall_pitch_max) * strength,
    roll = defaults.fall_roll * intensity * strength * side,
    duration = Lerp(intensity, defaults.fall_duration_min, defaults.fall_duration_max)
  }

  --- Lets plugins change the shake of the view that follows a landing. Called on the client
  -- when the local player lands on their feet faster than the fall shake needs, while the
  -- 'headbob' effect is applied. Change the fields in place; do not return anything from the
  -- handler, or the plugins after it are not asked.
  -- @param info [Map the shake: pitch (Number degrees the view dips at most), roll (Number
  --   degrees the view wobbles sideways, the sign being the side it starts on) and duration
  --   (Number seconds, 0 for no shake)]
  -- @param speed [Number downward speed right before the landing, in units per second]
  hook.Run('AdjustFallShake', info, speed)

  shake.pitch = to_number(info.pitch, 0)
  shake.roll = to_number(info.roll, 0)
  shake.duration = math.max(to_number(info.duration, 0), 0)
  shake.elapsed = 0
end

--- Works out what is added to the view angles this frame: notices landings, advances the
-- headbob and the fall shake, writes the result to `ScreenEffects.view` and runs the
-- AdjustViewEffects hook.
-- @param frame_time [Number seconds since the last frame]
function ScreenEffects:update_view(frame_time)
  local client = PLAYER
  local enabled = self:is_effect_enabled('headbob')
  local on_foot = client:Alive() and client:GetMoveType() == MOVETYPE_WALK and !client:InVehicle()
  local on_ground = client:IsOnGround()
  local velocity = client:GetVelocity()
  local info = bob_info

  if on_foot and !on_ground then
    fall_speed = math.max(-velocity.z, 0)
  elseif fall_speed > 0 then
    if enabled and on_foot and client:WaterLevel() < 2 then
      self:start_fall_shake(fall_speed)
    end

    fall_speed = 0
  end

  info.speed = 0
  info.pitch = 0
  info.yaw = 0
  info.roll = 0
  info.lean = 0

  if enabled and on_foot and on_ground then
    local speed = velocity:Length2D()

    if speed > defaults.bob_min_speed then
      local run_speed = math.max(to_number(Config.get('run_speed', 200), 200), 1)
      local fraction = math.min(speed / run_speed, 1)
      local strength = self:get_effect_strength('headbob')
      local sideways = math.Clamp(client:EyeAngles():Right():Dot(velocity) / run_speed, -1, 1)

      info.speed = Lerp(fraction, defaults.bob_rate_min, defaults.bob_rate_max)
      info.pitch = defaults.bob_pitch * fraction * strength
      info.yaw = defaults.bob_yaw * fraction * strength
      info.roll = defaults.bob_roll * fraction * strength
      info.lean = defaults.bob_lean * sideways * strength
    end

    --- Lets plugins change the headbob of the local player. Called on the client every frame
    -- while the player is alive, on foot and on the ground and the 'headbob' effect is
    -- applied, also when they stand still, in which case every field is 0. The view follows
    -- the result smoothly. Change the fields in place; do not return anything from the
    -- handler, or the plugins after it are not asked.
    -- @param info [Map the headbob: speed (Number how fast the sway cycles, in radians per
    --   second), pitch, yaw and roll (Number degrees of sway on each axis) and lean (Number
    --   degrees the view is rolled to one side, positive to the right)]
    hook.Run('AdjustHeadbob', info)
  end

  local blend = math.min(frame_time * defaults.bob_smoothing, 1)

  bob.speed = Lerp(blend, bob.speed, to_number(info.speed, 0))
  bob.pitch = Lerp(blend, bob.pitch, to_number(info.pitch, 0))
  bob.yaw = Lerp(blend, bob.yaw, to_number(info.yaw, 0))
  bob.roll = Lerp(blend, bob.roll, to_number(info.roll, 0))
  bob.lean = Lerp(blend, bob.lean, to_number(info.lean, 0))
  bob.phase = (bob.phase + bob.speed * frame_time) % (math.pi * 2)

  local pitch = math.sin(bob.phase * 2) * bob.pitch
  local yaw = math.sin(bob.phase) * bob.yaw
  local roll = math.cos(bob.phase) * bob.roll + bob.lean

  if shake.duration > 0 then
    shake.elapsed = shake.elapsed + frame_time

    local progress = shake.elapsed / shake.duration

    if progress < 1 then
      pitch = pitch + shake.pitch * math.sin(math.pi * math.sqrt(progress))
      roll = roll + shake.roll * math.sin(math.pi * 4 * progress) * (1 - progress)
    else
      shake.duration = 0
    end
  end

  view.pitch = pitch
  view.yaw = yaw
  view.roll = roll

  --- Lets plugins change what the Screen Effects plugin adds to the view angles of the local
  -- player. Called on the client every frame while the player is in the game with a
  -- character, after the headbob and the fall shake have been worked out, and also when the
  -- 'headbob' effect is turned off, in which case the angles are 0. The angles are not added
  -- while the player is seen in third person or looks through another entity. Change the
  -- fields in place; do not return anything from the handler, or the plugins after it are
  -- not asked.
  -- @param view [Map angles added to the view, in degrees: pitch (Number, positive looks
  --   down), yaw (Number, positive turns left) and roll (Number, positive tilts to the right)]
  hook.Run('AdjustViewEffects', view)
end
