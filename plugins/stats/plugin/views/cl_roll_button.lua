--- The roll button of the character sheet (`fl_stats_roll_button`), behind the `roll_button`
-- Lumen element: a Lumen button that shows the last roll of its stat or skill. Once pressed it
-- tumbles through the faces of a d20 until the server has answered, then lands on the total
-- with a flash, green for a critical success, red for a critical failure and in the accent
-- color otherwise, and keeps the total for a few seconds before it goes back to its text. The
-- tooltip holds the last result in words, the dice included. The element takes the props of
-- `button` and `roll_id`, the ID of the stat or the skill whose rolls it shows, which come
-- from `Stats:get_roll`. Derives from `lumen_button`.

local math_floor = math.floor
local math_clamp = math.Clamp

local face_time = 0.06
local flash_time = 0.9
local show_time = 6

local function mix(from, to, fraction)
  return Color(
    from.r + (to.r - from.r) * fraction,
    from.g + (to.g - from.g) * fraction,
    from.b + (to.b - from.b) * fraction,
    from.a + (to.a - from.a) * fraction
  )
end

local PANEL = {}

--- Sets the stat or the skill whose rolls the button shows.
-- @param id [String ID of the stat or the skill]
function PANEL:set_roll_id(id)
  self.roll_id = id
end

--- Works out what the button shows right now.
-- @param roll [Map the roll, as `Stats:get_roll` returns it, or nil]
-- @param now [Number RealTime]
-- @return [String 'tumbling' or 'landed', nil when the button shows its text]
local function get_roll_state(roll, now)
  if !roll then return end

  if roll.pending then
    return now - roll.started < Stats.roll_timeout and 'tumbling' or nil
  end

  if !roll.result then return end

  if now < roll.landed then
    return 'tumbling'
  elseif now < roll.landed + show_time then
    return 'landed'
  end
end

--- Puts the last result in the tooltip and plays a sound as the button lands on it, unless
-- it landed while the sheet was closed.
function PANEL:Think()
  self.BaseClass.Think(self)

  local roll = Stats:get_roll(self.roll_id)

  if !roll or !roll.result then return end

  if roll.text != self.roll_text then
    self.roll_text = roll.text
    self:SetTooltip(roll.text)
  end

  local now = RealTime()

  if !roll.sounded and now >= roll.landed then
    roll.sounded = true

    if now - roll.landed < 1 then
      local failed = roll.result.critical == 'failure'
      local sound_name = failed and 'button_click_danger_sound' or 'button_click_success_sound'

      surface.PlaySound(Theme.get_sound(sound_name))
    end
  end
end

--- Draws the icon of the button and a text next to it, centered.
-- @param text [String]
-- @param color [Color]
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:draw_roll_text(text, color, w, h)
  local font = self:get_font()
  local text_w = util.text_size(text, font)
  local icon_w = self:get_icon_size()
  local x = math_floor(w * 0.5 - (icon_w + text_w) * 0.5)
  local y = math_floor(h * 0.5)

  if icon_w > 0 then
    FontAwesome:draw(self.icon, x, y, self:get_icon_font_size(), color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
  end

  draw.SimpleText(text, font, x + icon_w, y, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

--- Draws the button: its text, the tumbling faces of a d20 while a roll is on its way, or the
-- total of the roll with a flash that fades into a tint of its color.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  local now = RealTime()
  local roll = Stats:get_roll(self.roll_id)
  local state = get_roll_state(roll, now)

  if !state then
    self.BaseClass.Paint(self, w, h)

    return
  end

  local background = self:get_background() or Theme.get_color('surface_raised')

  if state == 'tumbling' then
    Lumen.paint_box(self, w, h, background)

    self:draw_roll_text(tostring(math_floor(now / face_time) * 7 % 20 + 1), Theme.get_color('text_muted'), w, h)

    return
  end

  local result = roll.result
  local color = Theme.get_color('accent')

  if result.critical == 'success' then
    color = Theme.get_color('success')
  elseif result.critical == 'failure' then
    color = Theme.get_color('danger')
  end

  local flash = 1 - math_clamp((now - roll.landed) / flash_time, 0, 1)

  flash = flash * flash

  Lumen.paint_box(self, w, h, mix(background, color, 0.25 + 0.75 * flash))

  self:draw_roll_text(tostring(result.total), mix(color:lighten(40), color_white, flash), w, h)
end

vgui.Register('fl_stats_roll_button', PANEL, 'lumen_button')

local button_element = Lumen.find_element('button')

local function update_roll_button(panel, props, old_props)
  button_element.update(panel, props, old_props)
  panel:set_roll_id(props.roll_id)
end

Lumen.register_element('roll_button', {
  class = 'fl_stats_roll_button',
  style = button_element.style,
  mouse = true,
  update = update_roll_button
})
