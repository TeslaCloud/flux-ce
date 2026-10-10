--- Client side of the Screen Effects plugin: the list of effects, the checks that decide
-- whether an effect is applied, the state that is advanced every frame and the drawing of the
-- screen passes.
--
-- Whether an effect is applied, how strong the player wants it and what the `Adjust*` hooks
-- make of it is looked up eight times a second by `ScreenEffects:update_settings`; every
-- frame only moves the effects towards those values. The saturation, brightness and
-- contrast of the low health effect are folded into the color modification table of the
-- Color Modify plugin through `Flux.set_color_mod`, on top of whatever the schema has set
-- there, so that the screen is only color corrected once; without that plugin they are not
-- drawn. The distortion, the blur and the motion blur are passes of their own.
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

local clamp, max, min, approach = math.Clamp, math.max, math.min, math.Approach
local sin, cos, sqrt = math.sin, math.cos, math.sqrt
local lerp = Lerp
local pi = math.pi
local two_pi, four_pi = pi * 2, pi * 4

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

--- Whether each effect is applied and how strong the player wants it, as last looked up.
local enabled = { low_health = false, heartbeat = false, underwater = false, headbob = false }
local strengths = { low_health = 1, heartbeat = 1, underwater = 1, headbob = 1 }

--- What the AdjustScreenEffects and AdjustViewEffects hooks last made of the effects: the
-- values of the screen passes that a handler has replaced, by field, and what the handlers
-- have added to each view angle. Worked out eight times a second from what the effects
-- would draw on their own.
local screen_overrides = {}
local view_offsets = { pitch = 0, yaw = 0, roll = 0 }
local base_screen = {}
local adjusted_screen = {}
local adjusted_view = {}
local screen_fields = { 'saturation', 'brightness', 'contrast', 'motion_blur', 'refraction', 'blur' }
local view_fields = { 'pitch', 'yaw', 'roll' }

--- The color modification keys that the color pass writes, by field of
-- `ScreenEffects.screen`, with the value that leaves the picture alone; what the pass has
-- last written to each key and what it found there before, so that the values of the schema
-- are multiplied rather than replaced and put back once the effect is neutral; and whether
-- the pass has turned the color modification on itself, so that it turns it off again.
local color_keys = {
  saturation = { key = '$pp_colour_colour', neutral = 1 },
  brightness = { key = '$pp_colour_brightness', neutral = 0 },
  contrast = { key = '$pp_colour_contrast', neutral = 1 }
}
local color_written = {}
local color_base = {}
local color_mod_enabled_here = false

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

  return to_number(ClientSettings:get(effect.strength, 100), 100) * 0.01
end

--- Folds one value of the color pass into the color modification table of the Color Modify
-- plugin: the saturation and the contrast multiply what the schema has set there, the
-- brightness is added to it, and a neutral value puts the value of the schema back.
-- @param field [String 'saturation', 'brightness' or 'contrast']
-- @param value [Number value of the pass]
local function apply_color(field, value)
  local info = color_keys[field]
  local current = PLAYER.color_mod_table and PLAYER.color_mod_table[info.key]

  if current == nil then
    current = info.neutral
  end

  if color_written[field] == nil or current != color_written[field] then
    color_base[field] = current
  end

  local base = color_base[field]
  local result = base

  if value != info.neutral then
    result = field == 'brightness' and base + value or base * value
  end

  Flux.set_color_mod(info.key, result)

  color_written[field] = result
end

--- Writes the color pass to the Color Modify plugin and turns the color modification on
-- while the pass changes the picture, or off again once it does not, unless something
-- else has turned it on. Does nothing without the Color Modify plugin.
-- @param saturation [Number 1 leaves the colors alone]
-- @param brightness [Number 0 leaves it alone]
-- @param contrast [Number 1 leaves it alone]
local function apply_color_pass(saturation, brightness, contrast)
  if !isfunction(Flux.set_color_mod) or !IsValid(PLAYER) then return end

  apply_color('saturation', saturation)
  apply_color('brightness', brightness)
  apply_color('contrast', contrast)

  local active = saturation != 1 or brightness != 0 or contrast != 1

  if active and !PLAYER.color_mod then
    enable_color_mod()

    color_mod_enabled_here = true
  elseif !active and color_mod_enabled_here then
    Flux.disable_color_mod()

    color_mod_enabled_here = false
  end
end

--- Works out what the screen passes would draw from the levels of the effects alone.
-- @param target [Map table that the values are written to]
local function compute_screen(target)
  local blur_health = clamp(defaults.blur_health, 0.01, 1)

  target.saturation = max(1 - levels.damage, 0)
  target.brightness = 0
  target.contrast = 1
  target.motion_blur = clamp((levels.damage - (1 - blur_health)) / blur_health, 0, 1) * defaults.motion_blur
  target.refraction = levels.submerged * defaults.refraction
  target.blur = levels.submerged * defaults.blur
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

  return clamp(client:Health() / max(client:GetMaxHealth(), 1), 0, 1)
end

--- Puts everything back to where nothing is drawn, nothing is added to the view and no
-- heartbeat is heard, and gives the color modification table back to the schema. Called
-- every frame while the effects are not active.
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

  bob_info.speed = 0
  bob_info.pitch = 0
  bob_info.yaw = 0
  bob_info.roll = 0
  bob_info.lean = 0

  shake.duration = 0
  fall_speed = 0

  for i = 1, #screen_fields do
    screen_overrides[screen_fields[i]] = nil
  end

  for i = 1, #view_fields do
    view_offsets[view_fields[i]] = 0
  end

  apply_color_pass(1, 0, 1)

  self:stop_heartbeat()
end

--- Looks up what the effects are allowed to do: whether each of them is applied and how
-- strong the player wants it, what the headbob should be for the way the local player
-- moves, and what the AdjustScreenEffects and AdjustViewEffects hooks make of the effects.
-- Called eight times a second while the effects are active; the frames in between only
-- move the effects towards these values.
function ScreenEffects:update_settings()
  for k, v in ipairs(effect_order) do
    enabled[v] = self:is_effect_enabled(v)
    strengths[v] = self:get_effect_strength(v)
  end

  self:update_headbob_target()

  compute_screen(base_screen)

  for k, v in ipairs(screen_fields) do
    adjusted_screen[v] = base_screen[v]
  end

  --- Lets plugins change what the screen passes of the Screen Effects plugin draw. Called on
  -- the client eight times a second while the local player is in the game with a character,
  -- with what the low health and the underwater effect would draw on their own, and also
  -- when these effects are turned off, in which case the values are neutral. A field that a
  -- handler changes keeps the value it was given until the hook runs again; the others go
  -- on following the effects every frame. Change the fields in place; do not return
  -- anything from the handler, or the plugins after it are not asked.
  -- @param screen [Map values of the passes: saturation (Number, 1 leaves the colors alone and
  --   0 is gray), brightness (Number, 0 leaves it alone), contrast (Number, 1 leaves it alone),
  --   motion_blur (Number 0 to 1, 0 for none), refraction (Number how far the picture is
  --   distorted, 0 for none; the underwater effect uses 0.1) and blur (Number how far the
  --   picture is blurred, 0 for none; the underwater effect uses 2.5)]
  hook.Run('AdjustScreenEffects', adjusted_screen)

  for k, v in ipairs(screen_fields) do
    local value = to_number(adjusted_screen[v], base_screen[v])

    screen_overrides[v] = value != base_screen[v] and value or nil
  end

  for k, v in ipairs(view_fields) do
    adjusted_view[v] = view[v] - view_offsets[v]
  end

  --- Lets plugins change what the Screen Effects plugin adds to the view angles of the local
  -- player. Called on the client eight times a second while the player is in the game with a
  -- character, with what the headbob and the fall shake add on their own, and also when the
  -- 'headbob' effect is turned off, in which case the angles are 0. What a handler adds to
  -- or takes off an angle is kept and added every frame until the hook runs again. The
  -- angles are not added while the player is seen in third person or looks through another
  -- entity. Change the fields in place; do not return anything from the handler, or the
  -- plugins after it are not asked.
  -- @param view [Map angles added to the view, in degrees: pitch (Number, positive looks
  --   down), yaw (Number, positive turns left) and roll (Number, positive tilts to the right)]
  hook.Run('AdjustViewEffects', adjusted_view)

  for k, v in ipairs(view_fields) do
    view_offsets[v] = to_number(adjusted_view[v], view[v]) - (view[v] - view_offsets[v])
  end
end

--- Works out what the screen passes draw this frame: fades the low health and the underwater
-- effect towards where they should be, writes their values to `ScreenEffects.screen` with
-- what the AdjustScreenEffects hook has last replaced, and hands the color pass to the
-- Color Modify plugin.
-- @param frame_time [Number seconds since the last frame]
function ScreenEffects:update_screen(frame_time)
  local client = PLAYER
  local damage = 0
  local submerged = 0

  if enabled.low_health then
    damage = (1 - self:get_health_fraction()) * strengths.low_health
  end

  if enabled.underwater and client:WaterLevel() >= 3 and GetViewEntity() == client then
    submerged = strengths.underwater
  end

  levels.damage = approach(levels.damage, damage, frame_time * defaults.drain_speed)
  levels.submerged = approach(levels.submerged, submerged, frame_time * defaults.submerge_speed)

  compute_screen(screen)

  for k, v in pairs(screen_overrides) do
    screen[k] = v
  end

  apply_color_pass(to_number(screen.saturation, 1), to_number(screen.brightness, 0), to_number(screen.contrast, 1))
end

--- Draws the screen passes from the values in `ScreenEffects.screen`: the distortion, the
-- blur and the motion blur, each of them only if it would change the picture. The color
-- pass is drawn by the Color Modify plugin.
function ScreenEffects:draw_screen()
  local refraction = to_number(screen.refraction, 0)
  local blur = to_number(screen.blur, 0)
  local motion_blur = clamp(to_number(screen.motion_blur, 0), 0, 1)

  if refraction > 0 then
    draw_refraction(refraction)
  end

  if blur > 0 then
    draw_blur(blur)
  end

  if motion_blur > 0.01 then
    DrawMotionBlur(max(1 - motion_blur, 0.1), 1, 0)
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

  if !client:Alive() or fraction >= threshold or !enabled.heartbeat then
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

  info.interval = lerp(danger, defaults.heartbeat_slow, defaults.heartbeat_fast)
  info.volume = lerp(danger, defaults.heartbeat_quiet, defaults.heartbeat_loud) * strengths.heartbeat
  info.pitch = lerp(danger, 100, defaults.heartbeat_pitch)

  --- Lets plugins change the next beat of the low health heartbeat. Called on the client right
  -- before every beat, which is not every frame. Change the fields in place; do not return
  -- anything from the handler, or the plugins after it are not asked.
  -- @param info [Map the beat: interval (Number seconds until the beat after this one, at
  --   least 0.1), volume (Number 0 to 1, 0 skips this beat) and pitch (Number percent, 100
  --   being the normal pitch)]
  -- @param fraction [Number how much of their health the local player has left, 0 to 1]
  hook.Run('AdjustHeartbeat', info, fraction)

  self.next_heartbeat = cur_time + max(to_number(info.interval, defaults.heartbeat_slow), 0.1)

  local volume = clamp(to_number(info.volume, 0), 0, 1)

  if volume <= 0 then return end

  local pitch = clamp(to_number(info.pitch, 100), 1, 255)

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

  local intensity = clamp((speed - min_speed) / max(defaults.fall_max_speed - min_speed, 1), 0, 1)
  local strength = strengths.headbob
  local side = math.random(2) == 1 and 1 or -1
  local info = {
    pitch = lerp(intensity, defaults.fall_pitch_min, defaults.fall_pitch_max) * strength,
    roll = defaults.fall_roll * intensity * strength * side,
    duration = lerp(intensity, defaults.fall_duration_min, defaults.fall_duration_max)
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
  shake.duration = max(to_number(info.duration, 0), 0)
  shake.elapsed = 0
end

--- Works out what the headbob should be for the way the local player moves right now and
-- runs the AdjustHeadbob hook; the view follows the result smoothly every frame. Called
-- eight times a second while the effects are active.
function ScreenEffects:update_headbob_target()
  local client = PLAYER
  local info = bob_info

  info.speed = 0
  info.pitch = 0
  info.yaw = 0
  info.roll = 0
  info.lean = 0

  if !enabled.headbob or !client:Alive() or !client:IsOnGround() then return end
  if client:GetMoveType() != MOVETYPE_WALK or client:InVehicle() then return end

  local velocity = client:GetVelocity()
  local speed = velocity:Length2D()

  if speed > defaults.bob_min_speed then
    local run_speed = max(to_number(Config.get('run_speed', 200), 200), 1)
    local fraction = min(speed / run_speed, 1)
    local strength = strengths.headbob
    local sideways = clamp(client:EyeAngles():Right():Dot(velocity) / run_speed, -1, 1)

    info.speed = lerp(fraction, defaults.bob_rate_min, defaults.bob_rate_max)
    info.pitch = defaults.bob_pitch * fraction * strength
    info.yaw = defaults.bob_yaw * fraction * strength
    info.roll = defaults.bob_roll * fraction * strength
    info.lean = defaults.bob_lean * sideways * strength
  end

  --- Lets plugins change the headbob of the local player. Called on the client eight times
  -- a second while the player is alive, on foot and on the ground and the 'headbob' effect
  -- is applied, also when they stand still, in which case every field is 0. The view
  -- follows the result smoothly. Change the fields in place; do not return anything from
  -- the handler, or the plugins after it are not asked.
  -- @param info [Map the headbob: speed (Number how fast the sway cycles, in radians per
  --   second), pitch, yaw and roll (Number degrees of sway on each axis) and lean (Number
  --   degrees the view is rolled to one side, positive to the right)]
  hook.Run('AdjustHeadbob', info)
end

--- Works out what is added to the view angles this frame: notices landings, advances the
-- headbob towards what `ScreenEffects:update_headbob_target` has last asked for and the
-- fall shake, and writes the result to `ScreenEffects.view` with what the
-- AdjustViewEffects hook has last added.
-- @param frame_time [Number seconds since the last frame]
function ScreenEffects:update_view(frame_time)
  local client = PLAYER
  local on_foot = client:Alive() and client:GetMoveType() == MOVETYPE_WALK and !client:InVehicle()
  local info = bob_info

  if on_foot and !client:IsOnGround() then
    fall_speed = max(-client:GetVelocity().z, 0)
  elseif fall_speed > 0 then
    if enabled.headbob and on_foot and client:WaterLevel() < 2 then
      self:start_fall_shake(fall_speed)
    end

    fall_speed = 0
  end

  local blend = min(frame_time * defaults.bob_smoothing, 1)

  bob.speed = lerp(blend, bob.speed, to_number(info.speed, 0))
  bob.pitch = lerp(blend, bob.pitch, to_number(info.pitch, 0))
  bob.yaw = lerp(blend, bob.yaw, to_number(info.yaw, 0))
  bob.roll = lerp(blend, bob.roll, to_number(info.roll, 0))
  bob.lean = lerp(blend, bob.lean, to_number(info.lean, 0))
  local phase = (bob.phase + bob.speed * frame_time) % two_pi

  bob.phase = phase

  local pitch = sin(phase * 2) * bob.pitch
  local yaw = sin(phase) * bob.yaw
  local roll = cos(phase) * bob.roll + bob.lean

  if shake.duration > 0 then
    local elapsed = shake.elapsed + frame_time

    shake.elapsed = elapsed

    local progress = elapsed / shake.duration

    if progress < 1 then
      pitch = pitch + shake.pitch * sin(pi * sqrt(progress))
      roll = roll + shake.roll * sin(four_pi * progress) * (1 - progress)
    else
      shake.duration = 0
    end
  end

  view.pitch = pitch + view_offsets.pitch
  view.yaw = yaw + view_offsets.yaw
  view.roll = roll + view_offsets.roll
end
