--- Client-side hooks of the Cinematics plugin: they give the theme its cinematic options,
-- colors and fonts, run the timeline, draw the cinematics above the HUD, hide the HUD elements
-- that would sit on the bars, play the intro when a character is loaded and queue the
-- cinematics that the server sends.

--- Sets the options, colors and fonts of the cinematics on the theme that was loaded.
-- @param current_theme [ThemeBase]
function Cinematics:OnThemeLoaded(current_theme)
  local defaults = self.defaults
  local main_font = current_theme:get_font('main_font', 'flRoboto')
  local light_font = current_theme:get_font('light_font', 'flRobotoLight')

  current_theme:set_option('cinematic_bar_size', defaults.bar_size)
  current_theme:set_option('cinematic_duration', defaults.duration)
  current_theme:set_option('cinematic_slide_time', defaults.slide_time)
  current_theme:set_option('cinematic_fade_time', defaults.fade_time)

  current_theme:set_color('cinematic_bars', Color(0, 0, 0))
  current_theme:set_color('cinematic_text', Color(255, 255, 255))
  current_theme:set_color('cinematic_title', Color(255, 255, 255))

  current_theme:set_font('cinematic_caption', main_font, math.scale(26))
  current_theme:set_font('cinematic_title', light_font, math.scale(72))
  current_theme:set_font('cinematic_subtitle', light_font, math.scale(30))
end

--- Advances the timeline of the cinematics every frame while there is anything to play.
function Cinematics:Think()
  if self.stage or self.queue[1] then
    self:advance(FrameTime())
  end
end

--- Draws the letterbox bars and the text of the cinematic that is being played. This hook runs
-- right after HUDPaint, which puts the cinematic above everything the HUD has drawn.
function Cinematics:HUDDrawScoreBoard()
  if self:is_active() or self.current then
    self:draw(ScrW(), ScrH())
  end
end

--- Hides the top bars while the letterbox bars are on screen. Bars of the other types, such
-- as the respawn bar, are drawn in the middle of the screen and stay visible.
-- @param bar [Map bar data]
-- @return [Boolean false for a top bar while the letterbox bars are on screen, otherwise nil]
function Cinematics:ShouldDrawBar(bar)
  if bar.type == BAR_TOP and self:is_active() then
    return false
  end
end

--- Keeps the info display from being drawn while the letterbox bars are on screen.
-- @param icons [Map all of the registered icons by ID]
-- @return [Boolean true while the letterbox bars are on screen, otherwise nil]
function Cinematics:PreDrawInfoDisplay(icons)
  if self:is_active() then
    return true
  end
end

--- Hides the crosshair while the letterbox bars are on screen.
-- @return [Boolean false while the letterbox bars are on screen, otherwise nil]
function Cinematics:ShouldHUDPaintCrosshair()
  if self:is_active() then
    return false
  end
end

--- Plays the intro when the local player loads a character for the first time since joining,
-- unless the 'cinematic_intro' config is off.
-- @param char_id [Number ID of the character that has been loaded]
function Cinematics:PostCharacterLoaded(char_id)
  if self.intro_played then return end

  self.intro_played = true

  if Config.get('cinematic_intro', true) then
    self:play_intro(char_id)
  end
end

Cable.receive('fl_cinematic_show', function(cinematic)
  if !IsValid(PLAYER) or !PLAYER:has_initialized() then return end
  if PLAYER.is_character_loaded and !PLAYER:is_character_loaded() then return end

  Cinematics:add(cinematic)
end)

Cable.receive('fl_cinematic_clear', function()
  Cinematics:clear()
end)
