--- HUD bars: horizontal progress bars such as a respawn timer or a "getting up" timer. A bar
-- is a table of settings registered under an ID with `Flux.Bars:register`: its text, color,
-- value and maximum, position and size, and optionally a `callback` that returns its current
-- value. The `type` of a bar decides how it is laid out. `BAR_TOP` bars are stacked from the
-- top left corner of the screen in order of their `priority` and are drawn together by
-- `Flux.Bars:DrawTopBars`, which the gamemode calls while it paints the HUD of a living
-- player. Bars of the other types (`BAR_MANUAL`, `BAR_HIDDEN`) keep the position they were
-- registered with and are drawn by their owner with `Flux.Bars:draw`, usually from a HUD
-- paint hook.
--
-- Every `LazyTick` the top bars are repositioned and the bars that have a callback get their
-- value refreshed; other bars are updated with `Flux.Bars:set_value`, which animates the fill
-- toward the new value. Part of a bar can be blocked off with `Flux.Bars:hinder_value`. A bar
-- is only drawn while its value is inside its display range (above `min_display` and not above
-- `display`). The drawing itself is done by the active theme through the `DrawBarBackground`,
-- `DrawBarFill`, `DrawBarHindrance` and `DrawBarTexts` theme hooks, and plugins can step in
-- with the bar hooks (`ShouldDrawBar`, `PreDrawBar`, `AdjustBarPos`, `AdjustBarInfo` and so
-- on).
-- @module [Flux.Bars]

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

  --- Called on the client after a HUD bar has been registered or overwritten with
  -- `Flux.Bars:register`. Not called when a bar with this ID already exists and is kept.
  -- @param bar [Map the stored bar, with the defaults filled in]
  -- @param id [String bar ID]
  -- @param force [Boolean true if an existing bar with this ID was allowed to be overwritten,
  --   which is always the case in development mode]
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

    if bar.hinder_value != new_value then
      bar.hinder_value = math.Clamp(new_value, 0, bar.max_value)
    end
  end
end

--- Rebuilds the list of top bars grouped by priority. Bars that the 'ShouldDrawBar' hook
-- returns false for are left out.
-- @return [Map priority mapped to a List<String> of bar IDs]
function Flux.Bars:prioritize()
  sorted = {}

  for k, v in pairs(stored) do
    if hook.Run('ShouldDrawBar', v) == false then
      continue
    end

    --- Called on the client for every bar that passes `ShouldDrawBar`, right before the bar is
    -- sorted into the prioritized list of top bars. This happens every `LazyTick` and is the
    -- place to change the `priority` of a bar.
    -- @param bar [Map bar data]
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
        --- Lets plugins offset a top bar while the bars are being stacked. Called on the
        -- client for every `BAR_TOP` bar each time the bars are repositioned, which happens
        -- every `LazyTick`. The vertical offset is added to the bar's place in the stack, the
        -- horizontal offset to the x position of the bar; the offset of the previous call is
        -- taken back first, so it does not add up from call to call.
        -- @param bar [Map bar data]
        -- @return [Number horizontal offset in pixels, Number vertical offset in pixels; each
        --   is 0 when nothing is returned]
        local off_x, off_y = hook.Run('AdjustBarPos', bar)
        off_x = off_x or 0
        off_y = off_y or 0

        bar.y = last_y + off_y
        bar.x = bar.x - (bar.offset_x or 0) + off_x
        bar.offset_x = off_x
        last_y = last_y + bar.height + bar.spacing
      end
    end
  end
end

--- Draws the bar with the specified ID using the active theme. Does nothing if the bar does
-- not exist or the 'ShouldDrawBar' hook returns false for it.
-- @param id [String bar ID]
function Flux.Bars:draw(id)
  local bar_info = self:get(id)

  if bar_info then
    --- Called on the client when a bar is about to be drawn, before the `PreDrawBar` theme
    -- hook and before `ShouldDrawBar` is asked. Flux's own handler works out the fill width of
    -- the bar here (advancing its value animation) and converts its texts to upper case.
    -- @param bar_info [Map bar data]
    hook.Run('PreDrawBar', bar_info)
    Theme.call('PreDrawBar', bar_info)

    --- Asks whether a HUD bar should be drawn. Called on the client by `Flux.Bars:draw` every
    -- time a bar is drawn, and by `Flux.Bars:prioritize` for every registered bar when the top
    -- bars are sorted. The bar is drawn unless a handler returns false. Flux's own handler
    -- returns false while the value of the bar is above its `display` setting or not above
    -- its `min_display` setting, and nothing otherwise, which leaves the decision to the
    -- handlers that run after it.
    -- @param bar_info [Map bar data]
    -- @return [Boolean Return false to hide the bar]
    if hook.Run('ShouldDrawBar', bar_info) == false then
      return
    end

    Theme.call('DrawBarBackground', bar_info)

    --- Asks whether the fill of a bar should be drawn. Called on the client every time a bar
    -- is drawn, after its background. The fill is always drawn when the value of the bar is
    -- not 0.
    -- @param bar_info [Map bar data]
    -- @return [Boolean Return true to draw the fill even though the value of the bar is 0]
    if hook.Run('ShouldFillBar', bar_info) or bar_info.value != 0 then
      Theme.call('DrawBarFill', bar_info)
    end

    if bar_info.hinder_display and bar_info.hinder_display <= bar_info.hinder_value then
      Theme.call('DrawBarHindrance', bar_info)
    end

    Theme.call('DrawBarTexts', bar_info)

    --- Called on the client after a bar has been drawn, before the `PostDrawBar` theme hook.
    -- Not called for bars that `ShouldDrawBar` has hidden.
    -- @param bar_info [Map bar data]
    hook.Run('PostDrawBar', bar_info)
    Theme.call('PostDrawBar', bar_info)
  end
end

--- Draws every bar from the prioritized list of top bars. The gamemode calls it every frame
-- while it paints the HUD of a living player, along with the info displays.
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
  --- Hook handlers of the bars library, registered as `FLBarHooks`: they keep the bars
  -- positioned and up to date, animate their fill and hide them outside their display range.
  local Bars = {}

  --- Repositions the top bars and refreshes the value of every bar that has a callback.
  function Bars:LazyTick()
    if IsValid(PLAYER) then
      Flux.Bars:position()

      for k, v in pairs(stored) do
        if v.callback then
          Flux.Bars:set_value(v.id, v.callback(stored[k]))
        end

        --- Called on the client for every registered bar each `LazyTick`, after the callback
        -- of the bar has refreshed its value. Handlers can change the settings of the bar in
        -- place.
        -- @param id [String bar ID]
        -- @param bar [Map bar data]
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
  -- @return [Boolean false if the bar should not be drawn, nothing otherwise]
  function Bars:ShouldDrawBar(bar)
    if bar.display < bar.value or bar.min_display >= bar.value then
      return false
    end
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
