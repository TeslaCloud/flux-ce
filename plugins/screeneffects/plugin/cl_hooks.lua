--- Client-side hooks of the Screen Effects plugin: they advance the effects every frame, draw
-- the screen passes, add the headbob and the fall shake to the view and register the settings
-- of the effects with the Settings plugin.

local category = 'settings.categories.screen_effects'

--- Decides whether the switch of an effect is listed in the settings menu: only while the
-- server allows the effect.
-- @param setting [Map setting definition, with the effect ID in its effect field]
-- @return [Boolean]
local function is_switch_visible(setting)
  return ScreenEffects:is_effect_allowed(setting.effect)
end

--- Decides whether the strength slider of an effect is listed in the settings menu: only while
-- the server allows the effect and the player has it turned on.
-- @param setting [Map setting definition, with the effect ID in its effect field]
-- @return [Boolean]
local function is_strength_visible(setting)
  local effect = ScreenEffects.effects[setting.effect]

  return ScreenEffects:is_effect_allowed(setting.effect) and ClientSettings:get(effect.setting, true) != false
end

--- Looks up the settings of the effects and what the Adjust hooks make of them eight times a
-- second while the local player is in the game with a character.
function ScreenEffects:LazyTick()
  if self:effects_active() then
    self:update_settings()
  end
end

--- Advances the effects once a frame, or resets them while the local player is not in the game
-- with a character.
function ScreenEffects:Think()
  if !self:effects_active() then
    self:reset_effects()

    return
  end

  local frame_time = FrameTime()

  self:update_screen(frame_time)
  self:update_heartbeat()
  self:update_view(frame_time)
end

--- Draws the distortion, the blur and the motion blur of the effects. The color pass is
-- folded into the color modification of the Color Modify plugin, which draws it.
function ScreenEffects:RenderScreenspaceEffects()
  self:draw_screen()
end

--- Adds the headbob and the fall shake to the view angles. The angles are changed in place and
-- nothing is returned, so the handlers of other plugins and the gamemode still build the view
-- from them. Nothing is added while the local player is seen in third person or looks through
-- another entity.
-- @param client [Player]
-- @param origin [Vector]
-- @param angles [Angle]
-- @param fov [Number]
function ScreenEffects:CalcView(client, origin, angles, fov)
  if client:ShouldDrawLocalPlayer() or GetViewEntity() != client then return end

  local view = self.view

  angles.p = angles.p + (tonumber(view.pitch) or 0)
  angles.y = angles.y + (tonumber(view.yaw) or 0)
  angles.r = angles.r + (tonumber(view.roll) or 0)
end

--- Registers a switch and a strength slider for every effect with the Settings plugin. The
-- settings stay on the client: the effects are worked out there.
function ScreenEffects:RegisterClientSettings()
  for k, v in ipairs(self.effect_order) do
    local effect = self.effects[v]
    local phrase = 'settings.screen_effects.'..v

    ClientSettings:register_setting(effect.setting, {
      type = 'boolean',
      default = true,
      category = category,
      name = phrase..'.name',
      description = phrase..'.desc',
      effect = v,
      visible = is_switch_visible
    })

    ClientSettings:register_setting(effect.strength, {
      type = 'number',
      default = 100,
      min = 10,
      max = effect.max_strength,
      category = category,
      name = phrase..'.strength.name',
      description = phrase..'.strength.desc',
      effect = v,
      visible = is_strength_visible
    })
  end
end
