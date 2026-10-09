--- Client side of the Area Display plugin: decides whether an area is announced to the local
-- player, builds the notices and keeps the ones that are on screen.
-- A notice fades in, holds and fades out; its display style draws it and may change those
-- times. Areas entered while nothing can be shown, because the local player is dead or has no
-- character yet, are kept as pending and announced as soon as the HUD is drawn again.

local active = AreaDisplay.active or {}
local pending = AreaDisplay.pending or {}
local last_shown = {}
local last_request = {}
local request_interval = 10

AreaDisplay.active = active
AreaDisplay.pending = pending
AreaDisplay.defaults = {
  duration = 6,
  fade_time = 1.5,
  type_interval = 0.06,
  type_volume = 0.2,
  type_sound = 'common/talk.wav'
}

--- Converts a color that may have come over the network to an opaque Color. The Cinematics
-- plugin does it with `Cinematics.to_color` whenever it is loaded; the code here is only the
-- fallback for a server without it.
-- @param value [Color/Map color, or any table with the r, g and b fields]
-- @return [Color the color without its alpha, or nil if the value is not a color]
local function to_color(value)
  if Cinematics and isfunction(Cinematics.to_color) then
    return Cinematics.to_color(value)
  end

  if istable(value) and isnumber(value.r) and isnumber(value.g) and isnumber(value.b) then
    return Color(value.r, value.g, value.b)
  end
end

--- Checks whether the local player has area notices turned on. They are always on when the
-- Settings plugin is not loaded.
-- @return [Boolean]
function AreaDisplay:is_enabled()
  if ClientSettings then
    return ClientSettings:get('area_display', true) != false
  end

  return true
end

--- Checks whether a notice can be seen by the local player right now: they are initialized,
-- alive and, when the Characters plugin is loaded, have a character.
-- @return [Boolean]
function AreaDisplay:is_ready()
  if !IsValid(PLAYER) or !PLAYER:has_initialized() or !PLAYER:Alive() then
    return false
  end

  if PLAYER.is_character_loaded and !PLAYER:is_character_loaded() then
    return false
  end

  return true
end

--- Shows an area notice to the local player. Nothing is shown while the notices are turned
-- off or the local player cannot see them, or when a notice of the same area is on screen.
-- ```
-- AreaDisplay:add('City 17')
-- AreaDisplay:add({ text = 'Sector 7', style = 'typewriter', duration = 4 })
-- ```
-- @param info [String/Map text or language phrase of the notice, or a table with the fields:
--   text, style (ID of a display style, the default style if left out or not registered),
--   color (Color of the text, the 'area_display_text' theme color by default), duration
--   (seconds the notice stays once it has appeared, the 'area_display_duration' theme option
--   by default) and area_id (ID of the area the notice belongs to)]
-- @param area=nil [Map the area that is being announced, passed on to the hook]
-- @return [Map the notice, or nil if nothing is shown]
-- @see [AreaDisplay:announce]
function AreaDisplay:add(info, area)
  if isstring(info) then
    info = { text = info }
  end

  if !istable(info) or !isstring(info.text) or info.text == '' then return end
  if !self:is_enabled() or !self:is_ready() then return end

  if info.area_id != nil then
    for k, v in ipairs(active) do
      if v.area_id == info.area_id then
        return v
      end
    end
  end

  local text = t(info.text)
  local display = {
    text = text,
    style = info.style,
    color = to_color(info.color),
    duration = tonumber(info.duration),
    area_id = info.area_id
  }

  --- Called on the client right before an area notice is shown, once its text has been
  -- translated. Lets plugins change the notice in place, for example to put the time into
  -- its text. Do not return anything from a handler, or the plugins after it are not told.
  -- ```
  -- function MyPlugin:AdjustAreaDisplay(display, area)
  --   display.text = display.text:replace('%t', os.date('%H:%M'))
  -- end
  -- ```
  -- @param display [Map the notice about to be shown, with the fields: text (String, clear
  --   it to show nothing), style (String ID of the display style, may be nil for the
  --   default one), color (Color of the text, nil for the color of the theme), duration
  --   (Number of seconds the notice stays, nil for the default of the theme) and area_id
  --   (String ID of the area, nil for a notice that does not belong to one)]
  -- @param area [Map the area that is being announced, nil for a notice that does not belong
  --   to one]
  hook.Run('AdjustAreaDisplay', display, area)

  if !isstring(display.text) or display.text == '' then return end

  local style = self:find_style(display.style)

  if !style or (style.is_available and !style:is_available()) then
    style = self:find_style(self.default_style)
  end

  if !style then return end

  local defaults = self.defaults
  local fade_time = math.max(Theme.get_option('area_display_fade_time', defaults.fade_time), 0.01)

  display.style = style.id
  display.start_time = CurTime()
  display.fade_in = fade_time
  display.fade_out = fade_time
  display.hold = math.max(display.duration or Theme.get_option('area_display_duration', defaults.duration), 0)

  if style.start and style:start(display) == false then
    return display
  end

  table.insert(active, display)

  return display
end

--- Announces an area to the local player. An area that was announced less than
-- 'area_display_cooldown' seconds ago is skipped. A one-time area is not shown right away:
-- the server is asked first, and shows it if the player has not seen it before. If the local
-- player cannot see notices at the moment, the area is announced once they can, unless they
-- leave it first.
-- @param area [Map the area, with the `id`, `text`, `style` and `once` fields]
-- @param force=false [Boolean show the notice regardless of the cooldown and of the area
--   being a one-time one]
-- @return [Boolean true if the notice has been shown, false otherwise]
-- @see [AreaDisplay:add]
function AreaDisplay:announce(area, force)
  if !istable(area) or area.id == nil or !isstring(area.text) or area.text == '' then return false end
  if !self:is_enabled() then return false end

  if !self:is_ready() then
    pending[area.id] = force == true

    return false
  end

  local cur_time = CurTime()

  if !force then
    if area.once then
      local requested_at = last_request[area.id]

      if !requested_at or cur_time - requested_at >= request_interval then
        last_request[area.id] = cur_time

        Cable.send('fl_area_display_request', tostring(area.id))
      end

      return false
    end

    local shown_at = last_shown[area.id]

    if shown_at and cur_time - shown_at < Config.get('area_display_cooldown', 20) then
      return false
    end
  end

  last_shown[area.id] = cur_time

  return self:add({ text = area.text, style = area.style, area_id = area.id }, area) != nil
end

--- Announces the areas that were entered while the local player could not see notices.
function AreaDisplay:flush_pending()
  local queued = table.Copy(pending)

  table.Empty(pending)

  for id, force in pairs(queued) do
    local area = self:find_text_area(tostring(id))

    if area then
      self:announce(area, force)
    end
  end
end

--- Takes every notice off the screen and forgets the pending areas.
function AreaDisplay:clear()
  table.Empty(active)
  table.Empty(pending)
end

--- Returns the opacity of a notice at a point in time.
-- @param display [Map the notice]
-- @param cur_time [Number CurTime() to get the opacity at]
-- @return [Number opacity from 0 to 255, or nil if the notice is over]
function AreaDisplay:get_alpha(display, cur_time)
  local elapsed = cur_time - display.start_time

  if elapsed < display.fade_in then
    return math.Clamp(255 * elapsed / display.fade_in, 0, 255)
  end

  elapsed = elapsed - display.fade_in - display.hold

  if elapsed < 0 then
    return 255
  end

  if elapsed < display.fade_out then
    return 255 * (1 - elapsed / display.fade_out)
  end
end

--- Draws the notices that are on screen and drops the ones that are over. Notices of the
-- same style are stacked below one another.
-- @param cur_time [Number current CurTime()]
-- @param scrw [Number screen width]
-- @param scrh [Number screen height]
function AreaDisplay:draw(cur_time, scrw, scrh)
  local offsets = {}
  local index = 1

  while active[index] do
    local display = active[index]
    local style = self:find_style(display.style)
    local alpha = self:get_alpha(display, cur_time)

    if !alpha or !style or !style.draw then
      table.remove(active, index)
    else
      local offset = offsets[display.style] or 0

      offsets[display.style] = offset + (style:draw(display, alpha, scrw, scrh, offset) or 0)
      index = index + 1
    end
  end
end
