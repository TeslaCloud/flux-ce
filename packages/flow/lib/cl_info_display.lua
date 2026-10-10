--- The info display: a row of round icons in the top left corner of the HUD that each show a
-- percentage, such as health and armor. An icon is registered with `InfoDisplay:add` under an
-- ID, with a Font Awesome icon, a size and a `callback` that updates its `percentage` before
-- every draw. The icon is drawn dimmed and then filled with its color from the bottom up to
-- that percentage. It is hidden while the percentage is outside of the range between
-- `min_percentage` and `max_percentage`, so that the health icon, for example, only appears
-- once the player is hurt. Flux registers the 'health' and 'armor' icons itself and draws all
-- of the icons with `InfoDisplay:draw_all` from its HUD paint hook while the local player is
-- alive.

mod 'InfoDisplay'

local scale         = math.scale

local stored        = InfoDisplay.stored or {}
InfoDisplay.stored  = stored

local margin        = scale(26)
local last_x        = 0
local white         = Color(255, 255, 255)
local back_color    = Color(40, 40, 40, 120)

--- Adds an icon to the HUD info display. The icon is filled from the bottom
-- according to its percentage, and is hidden while the percentage is outside
-- of the (min_percentage, max_percentage) range.
-- ```
-- InfoDisplay:add('armor', {
--   icon = 'fa-shield-alt',
--   min_percentage = 2,
--   max_percentage = 101,
--   size = 80,
--   callback = function(data)
--     data.percentage = (PLAYER:Armor() / 100) * 100
--   end
-- })
-- ```
-- @param id [String unique ID, converted with string.to_id]
-- @param data [Map settings: icon, size, color, back_color, percentage, min_percentage,
--   max_percentage, offset_x, offset_y, and callback, which is called with this hash
--   before every draw; missing keys get defaults]
-- @return [InfoDisplay self, for chaining]
function InfoDisplay:add(id, data)
  id                  = id:to_id()

  data.id             = id
  data.min_percentage = data.min_percentage or nil
  data.max_percentage = data.max_percentage or 100
  data.size           = data.size           or 80
  data.icon           = data.icon           or 'fa-plus'
  data.color          = data.color          or white
  data.back_color     = data.back_color     or back_color
  data.circle         = data.circle         or false
  data.percentage     = data.percentage     or 100
  data.offset_x       = data.offset_x       or 0
  data.offset_y       = data.offset_y       or 0
  data.callback       = data.callback       or 0

  stored[id]          = data

  return self
end

--- Returns all of the registered info display icons.
-- @return [Map icon data by ID]
function InfoDisplay:all()
  return stored
end

--- Removes an icon from the info display.
-- @param id [String ID of the icon, exactly as it is stored]
-- @return [InfoDisplay self, for chaining]
function InfoDisplay:remove(id)
  stored[id] = nil
  return self
end

--- Sets the gap between the info display icons and the edges of the screen.
-- @param val [Number margin in pixels]
-- @return [InfoDisplay self, for chaining]
function InfoDisplay:set_margin(val)
  margin = val
  return self
end

--- Draws a single info display icon after running its callback. Can be prevented
-- with the 'PreDrawInfoDisplayItem' hook.
-- @param info [Map icon data, as stored by InfoDisplay#add]
-- @return [Number horizontal offset for the next icon, 0 if nothing was drawn]
function InfoDisplay:draw(info)
  --- Called on the client before an icon of the info display is drawn, before the callback of
  -- the icon runs.
  -- @param info [Map icon data, as stored by `InfoDisplay:add`]
  -- @return [Any Return any non-nil value to skip this icon]
  if hook.Run('PreDrawInfoDisplayItem', info) == nil then
    if isfunction(info.callback) then
      info.callback(info)
    end

    if info.max_percentage and info.max_percentage <= info.percentage then return 0 end
    if info.min_percentage and info.min_percentage >= info.percentage then return 0 end

    local size = scale(info.size)

    if isstring(info.icon) then
      local x_pos = last_x + margin
      local circle_size = size * 0.5
      local circle_x, circle_y = x_pos + circle_size, margin + circle_size
      local font_size = size * 0.8
      local half_size = font_size * 0.5
      local icon_x = circle_x - half_size + scale(info.offset_x)
      local icon_y = circle_y - half_size + scale(info.offset_y)

      FontAwesome:draw(info.icon, icon_x, icon_y, font_size, info.back_color)
      surface.SetDrawColor(info.back_color)
      surface.draw_circle_outline(circle_x, circle_y, circle_size, 3, 64)

      if !info.circle then
        local y_pos = size + margin

        render.SetScissorRect(x_pos, y_pos - size * 0.01 * info.percentage, x_pos + size, y_pos, true)
          FontAwesome:draw(info.icon, icon_x, icon_y, font_size, info.color)
          surface.SetDrawColor(info.color)
          surface.draw_circle_outline(circle_x, circle_y, circle_size, 3, 64)
        render.SetScissorRect(0, 0, 0, 0, false)
      end
    end

    return last_x + margin + size
  end

  return 0
end

--- Draws all of the registered info display icons next to each other. Can be prevented
-- with the 'PreDrawInfoDisplay' hook.
-- @return [InfoDisplay self, for chaining]
function InfoDisplay:draw_all()
  --- Called on the client every time the info display is about to be drawn.
  -- @param icons [Map all of the registered icons by ID]
  -- @return [Any Return any non-nil value to prevent the info display from being drawn]
  if hook.Run('PreDrawInfoDisplay', stored) == nil then
    for k, v in pairs(stored) do
      last_x = last_x + self:draw(v)
    end
  end

  last_x = 0

  return self
end

InfoDisplay:add('health', {
  icon = 'fa-plus',
  max_percentage = 95,
  size = 80,
  offset_x = 4,
  callback = function(data)
    data.percentage = (PLAYER:Health() / PLAYER:GetMaxHealth()) * 100
  end
})

InfoDisplay:add('armor', {
  icon = 'fa-shield-alt',
  min_percentage = 2,
  max_percentage = 101,
  size = 80,
  callback = function(data)
    data.percentage = (PLAYER:Armor() / 100) * 100
  end
})
