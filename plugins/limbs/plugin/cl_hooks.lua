--- Client-side hooks of the Limbs plugin: they register the client setting of the body
-- diagram, draw the diagram on the HUD and make the aim of a player with hurt arms drift.
-- The strength of the drift is looked up eight times a second; every frame only moves the
-- view along its path.

local diagram_alpha = 0
local sway_strength = 0
local sway_pitch = 0
local sway_yaw = 0

--- Strength of the aim drift the local player is due, as last looked up.
local aim_fraction = 0

--- Checks whether a player is holding a weapon that they could aim: any weapon, or a raised
-- one when the Raise Weapon plugin is loaded.
-- @param client [Player]
-- @return [Boolean]
local function is_aiming(client)
  if !IsValid(client:GetActiveWeapon()) then
    return false
  end

  if isfunction(client.is_weapon_raised) then
    return client:is_weapon_raised()
  end

  return true
end

--- Looks up how strongly the aim of the local player should drift: the 'aim' effect of
-- their limbs while they are alive, on foot and holding a weapon they could aim.
function Limbs:LazyTick()
  local fraction = 0

  if IsValid(PLAYER) and PLAYER:Alive() and !PLAYER:InVehicle() and is_aiming(PLAYER) then
    fraction = self:get_effect(PLAYER, 'aim')
  end

  aim_fraction = fraction
end

--- Forgets the colors of the diagram when a theme is loaded, so that they come from the
-- new theme.
-- @param current_theme [Theme the theme that has been loaded]
function Limbs:OnThemeLoaded(current_theme)
  self:reset_colors()
end

--- Registers the 'limbs_hud' client setting, which decides when the body diagram is shown.
function Limbs:RegisterClientSettings()
  ClientSettings:register_setting('limbs_hud', {
    type = 'choice',
    default = 'hurt',
    choices = {
      { value = 'hurt', name = 'settings.limbs_hud.hurt' },
      { value = 'always', name = 'settings.limbs_hud.always' },
      { value = 'never', name = 'settings.limbs_hud.never' }
    },
    category = 'settings.categories.interface',
    name = 'settings.limbs_hud.name',
    description = 'settings.limbs_hud.desc'
  })
end

--- Draws the body diagram in the bottom right corner of the HUD. It fades in while a limb
-- of the local player is hurt (or always, or never, as the 'limbs_hud' client setting says)
-- and is hidden while limb damage is disabled or cinematic bars are on screen. The theme
-- options 'limbs_diagram_x', 'limbs_diagram_y' and 'limbs_diagram_height' move and resize
-- it, and a theme that has a `DrawLimbDiagram(x, y, height, alpha)` method draws it instead
-- of `Limbs:draw_diagram`, unless that method returns nil.
-- @param cur_time [Number current CurTime()]
-- @param scrw [Number screen width]
-- @param scrh [Number screen height]
function Limbs:FLHUDPaint(cur_time, scrw, scrh)
  local mode = self:is_enabled() and self:get_hud_mode() or 'never'
  local visible = mode == 'always' or (mode == 'hurt' and self:is_any_damaged(PLAYER))

  if visible and Cinematics and Cinematics:is_active() then
    visible = false
  end

  diagram_alpha = math.Approach(diagram_alpha, visible and 1 or 0, FrameTime() * 4)

  if diagram_alpha <= 0 then return end

  --- Asks whether the body diagram of the Limbs plugin should be drawn on the HUD. Called on
  -- the client every frame in which the diagram is visible or fading out.
  -- @return [Boolean Return false to hide the diagram]
  if hook.Run('ShouldDrawLimbDiagram') == false then return end

  local offset_x, offset_y = Flux.global_ui_offset()
  local height = Theme.get_option('limbs_diagram_height') or math.scale(128)
  local margin = math.scale(48)
  local x = (Theme.get_option('limbs_diagram_x') or (scrw - height * 0.5 - margin)) + offset_x
  local y = (Theme.get_option('limbs_diagram_y') or (scrh - height - margin)) + offset_y

  if Theme.hook('DrawLimbDiagram', x, y, height, diagram_alpha) == nil then
    self:draw_diagram(x, y, height, diagram_alpha)
  end
end

--- Makes the aim of the local player drift while they hold a weapon with a hurt arm. The
-- view is moved along a slow, repeating path of up to `Limbs.sway_angle` degrees for a
-- crippled arm; only the difference to the previous frame is added, so the player keeps
-- control of their aim and the view returns to where it was once the drift stops. The
-- strength comes from the last `LazyTick`.
-- @param user_cmd [CUserCmd]
function Limbs:CreateMove(user_cmd)
  sway_strength = math.Approach(sway_strength, aim_fraction, FrameTime())

  local time = RealTime()
  local angle = sway_strength * self.sway_angle
  local pitch = (math.sin(time * 1.1) * 0.6 + math.sin(time * 2.3) * 0.4) * angle
  local yaw = (math.cos(time * 0.9) * 0.6 + math.sin(time * 1.7) * 0.4) * angle

  if pitch == sway_pitch and yaw == sway_yaw then return end

  local angles = user_cmd:GetViewAngles()

  angles.p = math.Clamp(angles.p + pitch - sway_pitch, -89, 89)
  angles.y = math.NormalizeAngle(angles.y + yaw - sway_yaw)

  sway_pitch = pitch
  sway_yaw = yaw

  user_cmd:SetViewAngles(angles)
end
