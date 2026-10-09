--- Client-side hooks of the Area Display plugin: they give the theme its area notice options,
-- color, sound and fonts, register the client setting, announce the text areas the local
-- player enters, draw the notices on the HUD and show the ones that the server sends.

--- Sets the options, the color, the sound and the fonts of the area notices on the theme that
-- was loaded.
-- @param current_theme [ThemeBase]
function AreaDisplay:OnThemeLoaded(current_theme)
  local defaults = self.defaults
  local main_font = current_theme:get_font('main_font', 'flRoboto')
  local light_font = current_theme:get_font('light_font', 'flRobotoLight')

  current_theme:set_option('area_display_duration', defaults.duration)
  current_theme:set_option('area_display_fade_time', defaults.fade_time)
  current_theme:set_option('area_display_type_interval', defaults.type_interval)
  current_theme:set_option('area_display_type_volume', defaults.type_volume)

  current_theme:set_color('area_display_text', Color(255, 255, 255))
  current_theme:set_sound('area_display_type', defaults.type_sound)

  current_theme:set_font('area_display_title', light_font, math.scale(56))
  current_theme:set_font('area_display_typewriter', main_font, math.scale(28))
end

--- Registers the 'area_display' client setting, which turns the area notices on and off.
function AreaDisplay:RegisterClientSettings()
  ClientSettings:register_setting('area_display', {
    type = 'boolean',
    default = true,
    category = 'settings.categories.interface',
    name = 'settings.area_display.name',
    description = 'settings.area_display.desc'
  })
end

--- Takes the notices off the screen when the local player turns them off.
-- @param id [String setting id]
-- @param value [Any new value of the setting]
-- @param old_value [Any previous value of the setting]
function AreaDisplay:ClientSettingChanged(id, value, old_value)
  if id == 'area_display' and value == false then
    self:clear()
  end
end

--- Announces the areas that were entered while the HUD was hidden and draws the notices
-- that are on screen. The hook only runs while the local player is alive and the HUD is
-- shown.
-- @param cur_time [Number current CurTime()]
-- @param scrw [Number screen width]
-- @param scrh [Number screen height]
function AreaDisplay:FLHUDPaint(cur_time, scrw, scrh)
  if next(self.pending) != nil then
    self:flush_pending()
  end

  if self.active[1] then
    self:draw(cur_time, scrw, scrh)
  end
end

--- Announces the text areas the local player is standing in when their client has finished
-- loading. The Areas API reports an area once, at the moment the player enters it, and for a
-- player who joins inside of one that is before their client is able to receive anything,
-- so the area at the spawn point would never be announced. By the time this hook runs the
-- areas have arrived from the server; the notice is kept as pending until the local player
-- can see it.
function AreaDisplay:PlayerInitialized()
  if !IsValid(PLAYER) then return end

  for k, area in ipairs(self:find_text_areas_at(PLAYER:GetPos())) do
    self:announce(area)
  end
end

--- Announces the text area that the local player has entered.
-- @param actor [Player the player who entered the area]
-- @param area [Map the area that was entered]
-- @param cur_time [Number CurTime at the moment of entering]
function AreaDisplay:PlayerEnteredTextArea(actor, area, cur_time)
  self:announce(area)
end

--- Forgets the text area that the local player has left, if it was still waiting to be
-- announced.
-- @param actor [Player the player who left the area]
-- @param area [Map the area that was left]
-- @param cur_time [Number CurTime at the moment of leaving]
function AreaDisplay:PlayerLeftTextArea(actor, area, cur_time)
  if area.id != nil then
    self.pending[area.id] = nil
  end
end

Cable.receive('fl_area_display_show', function(info, area_id)
  local area = AreaDisplay:find_text_area(area_id)

  if istable(info) or isstring(info) then
    AreaDisplay:add(info, area)
  elseif area then
    AreaDisplay:announce(area, true)
  end
end)
