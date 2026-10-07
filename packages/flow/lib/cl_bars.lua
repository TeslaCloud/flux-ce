if !font then require_relative 'cl_font' end
if !Flux.Lang then require_relative 'sh_lang' end

mod 'Flux::Bars'

local stored              = Flux.Bars.stored or {}
local sorted              = Flux.Bars.sorted or {}
Flux.Bars.stored          = stored
Flux.Bars.sorted          = sorted
Flux.Bars.default_x       = 8
Flux.Bars.default_y       = 8
Flux.Bars.default_w       = math.scale_width(312)
Flux.Bars.default_h       = 18
Flux.Bars.default_spacing = 6

--- Registers a HUD bar. If a bar with this ID already exists it is returned untouched,
-- unless force is set or Flux runs in development mode.
-- ```
-- Flux.Bars:register('getup', {
--   text = t'ui.hud.bar_text.getup',
--   color = Color(50, 200, 50),
--   max_value = 100,
--   x = ScrW() * 0.5 - Flux.Bars.default_w * 0.5,
--   y = ScrH() * 0.5 - 8,
--   height = 20,
--   type = BAR_MANUAL
-- })
-- ```
-- @param id [String unique bar ID]
-- @param data [Map bar settings such as text, color, value, max_value, x, y, width, height,
--   priority, type (BAR_TOP, BAR_MANUAL or BAR_HIDDEN), font and callback (receives the bar,
--   returns its new value); missing keys get defaults]
-- @param force=false [Boolean overwrite an existing bar with the same ID]
-- @return [Map the stored bar, or nil if no data was given]
function Flux.Bars:register(id, data, force)
  if !data then return end

  force = force or Flux.development

  if stored[id] and !force then
    return stored[id]
  end

  stored[id] = {
    id = id,
    text = data.text or '',
    color = data.color or Color(200, 90, 90),
    max_value = data.max_value or 100,
    hinder_color = data.hinder_color or Color(255, 0, 0),
    hinder_text = data.hinder_text or '',
    display = data.display or 100,
    min_display = data.min_display or 0,
    hinder_display = data.hinder_display or false,
    value = data.value or 0,
    hinder_value = data.hinder_value or 0,
    x = data.x or self.default_x,
    y = data.y or self.default_y,
    width = data.width or self.default_w,
    height = data.height or self.default_h,
    corner_radius = data.corner_radius or 0,
    priority = data.priority or table.Count(stored),
    type = data.type or BAR_TOP,
    font = data.font or 'text_bar',
    spacing = data.spacing or self.default_spacing,
    text_offset = data.text_offset or 1,
    callback = data.callback
  }

  hook.Run('OnBarRegistered', stored[id], id, force)

  return stored[id]
end

--- Returns the bar registered under the specified ID.
-- @param id [String bar ID]
-- @return [Map the bar, or false if it does not exist]
function Flux.Bars:get(id)
  if stored[id] then
    return stored[id]
  end

  return false
end

--- Sets the value of a bar, clamped between 0 and its max value, and starts the fill
-- animation toward it. Calls the 'PreBarValueSet' theme hook first.
-- @param id [String bar ID]
-- @param new_value [Number]
function Flux.Bars:set_value(id, new_value)
  local bar = self:get(id)

  if bar then
    Theme.call('PreBarValueSet', bar, bar.value, new_value)

    if bar.value != new_value then
      if bar.hinder_display and bar.hinder_value then
        bar.value = math.Clamp(new_value, 0, bar.max_value - bar.hinder_value + 2)
      end

      bar.interpolated = util.cubic_ease_in_out_t(150, bar.value, new_value)
      bar.value = math.Clamp(new_value, 0, bar.max_value)
    end
  end
end

--- Sets the hindrance value of a bar (the part of it that is blocked off), clamped between
-- 0 and its max value. Calls the 'PreBarHinderValueSet' theme hook first.
-- @param id [String bar ID]
-- @param new_value [Number]
function Flux.Bars:hinder_value(id, new_value)
  local bar = self:get(id)

  if bar then
    Theme.call('PreBarHinderValueSet', bar, bar.hinder_value, new_value)

    if bar.value != new_value then
      bar.hinder_value = math.Clamp(new_value, 0, bar.max_value)
    end
  end
end

--- Rebuilds the list of top bars grouped by priority. Bars rejected by the 'ShouldDrawBar'
-- hook are left out.
-- @return [Map priority mapped to a List<String> of bar IDs]
function Flux.Bars:prioritize()
  sorted = {}

  for k, v in pairs(stored) do
    if !hook.Run('ShouldDrawBar', v) then
      continue
    end

    hook.Run('PreBarPrioritized', v)

    sorted[v.priority] = sorted[v.priority] or {}

    if v.type == BAR_TOP then
      table.insert(sorted[v.priority], v.id)
    end
  end

  return sorted
end

--- Recalculates the positions of all top bars, stacking them vertically in order of priority.
-- Plugins can offset each bar through the 'AdjustBarPos' hook.
function Flux.Bars:position()
  self:prioritize()

  local last_y = self.default_y

  for priority, ids in pairs(sorted) do
    for k, v in pairs(ids) do
      local bar = self:get(v)

      if bar and bar.type == BAR_TOP then
        local off_x, off_y = hook.Run('AdjustBarPos', bar)
        off_x = off_x or 0
        off_y = off_y or 0

        bar.y = last_y + off_y
        bar.x = bar.x + off_x
        last_y = last_y + bar.height + bar.spacing
      end
    end
  end
end

--- Draws the bar with the specified ID using the active theme. Does nothing if the bar does
-- not exist or the 'ShouldDrawBar' hook rejects it.
-- @param id [String bar ID]
function Flux.Bars:draw(id)
  local bar_info = self:get(id)

  if bar_info then
    hook.Run('PreDrawBar', bar_info)
    Theme.call('PreDrawBar', bar_info)

    if !hook.Run('ShouldDrawBar', bar_info) then
      return
    end

    Theme.call('DrawBarBackground', bar_info)

    if hook.Run('ShouldFillBar', bar_info) or bar_info.value != 0 then
      Theme.call('DrawBarFill', bar_info)
    end

    if bar_info.hinder_display and bar_info.hinder_display <= bar_info.hinder_value then
      Theme.call('DrawBarHindrance', bar_info)
    end

    Theme.call('DrawBarTexts', bar_info)

    hook.Run('PostDrawBar', bar_info)
    Theme.call('PostDrawBar', bar_info)
  end
end

--- Draws every bar from the prioritized list of top bars.
function Flux.Bars:DrawTopBars()
  for priority, ids in pairs(sorted) do
    for k, v in ipairs(ids) do
      self:draw(v)
    end
  end
end

--- Merges the specified settings into an existing bar.
-- @param id [String bar ID]
-- @param data [Map bar settings to overwrite, same keys as in Flux.Bars#register]
function Flux.Bars:adjust(id, data)
  local bar = self:get(id)

  if bar then
    table.Merge(bar, data)
  end
end

do
  local Bars = {}

  --- Repositions the top bars and refreshes the value of every bar that has a callback.
  function Bars:LazyTick()
    if IsValid(PLAYER) then
      Flux.Bars:position()

      for k, v in pairs(stored) do
        if v.callback then
          Flux.Bars:set_value(v.id, v.callback(stored[k]))
        end

        hook.Run('AdjustBarInfo', k, stored[k])
      end
    end
  end

  --- Calculates the fill width of the bar, advancing its value animation, and converts
  -- its texts to upper case.
  -- @param bar [Map bar data]
  function Bars:PreDrawBar(bar)
    bar.cur_i = bar.cur_i or 1

    bar.real_fill_width = bar.width * (bar.value / bar.max_value)

    if bar.interpolated == nil then
      bar.fill_width = bar.real_fill_width
    else
      if bar.cur_i > 150 then
        bar.interpolated = nil
        bar.cur_i = 1
      else
        bar.fill_width = bar.width * (bar.interpolated[math.Round(bar.cur_i)] / bar.max_value)
        bar.cur_i = bar.cur_i + math.Clamp(math.Round(1 * (FrameTime() / 0.006)), 1, 10)
      end
    end

    bar.text = string.utf8upper(bar.text)
    bar.hinder_text = string.utf8upper(bar.hinder_text)
  end

  --- Hides the bar while its value is outside of its display range.
  -- @param bar [Map bar data]
  -- @return [Boolean false if the bar should not be drawn]
  function Bars:ShouldDrawBar(bar)
    if bar.display < bar.value or bar.min_display >= bar.value then
      return false
    end

    return true
  end

  Plugin.add_hooks('FLBarHooks', Bars)

  Flux.Bars:register('respawn', {
    text = t'ui.hud.bar_text.respawn',
    color = Color(50, 200, 50),
    max_value = 100,
    x = ScrW() * 0.5 - Flux.Bars.default_w * 0.5,
    y = ScrH() * 0.5 - 8,
    text_offset = 1,
    height = 16,
    type = BAR_MANUAL
  })
end
