mod 'InfoDisplay'

local stored        = InfoDisplay.stored or {}
InfoDisplay.stored  = stored

local margin        = math.scale(26)
local last_x        = 0
local white         = Color(255, 255, 255)
local back_color    = Color(40, 40, 40, 120)

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

function InfoDisplay:all()
  return stored
end

function InfoDisplay:remove(id)
  stored[id] = nil
  return self
end

function InfoDisplay:set_margin(val)
  margin = val
  return self
end

function InfoDisplay:draw(info)
  if hook.run('PreDrawInfoDisplayItem', info) == nil then
    if isfunction(info.callback) then
      info.callback(info)
    end

    if info.max_percentage and info.max_percentage <= info.percentage then return 0 end
    if info.min_percentage and info.min_percentage >= info.percentage then return 0 end

    local fa_icon = isstring(info.icon)
    local size = math.scale(info.size)
    local x_pos, y_pos = last_x + margin, size + margin
    local circle_size = size * 0.5
    local circle_pos = x_pos + circle_size
    local font_size = size * 0.8
    local half_size = font_size * 0.5
    local ox, oy = math.scale(info.offset_x), math.scale(info.offset_y)

    if fa_icon then
      FontAwesome:draw(info.icon, x_pos + circle_size - half_size + ox, margin + circle_size - half_size + oy, font_size, info.back_color)
      surface.SetDrawColor(info.back_color)
      surface.draw_circle_outline(x_pos + size * 0.5, margin + size * 0.5, circle_size, 3, 64)
    end

    if !info.circle then
      if fa_icon then
        render.SetScissorRect(x_pos, y_pos - (size / 100 * info.percentage), x_pos + size, y_pos, true)
          FontAwesome:draw(info.icon, x_pos + circle_size - half_size + ox, margin + circle_size - half_size + oy, font_size, info.color)
          surface.SetDrawColor(info.color)
          surface.draw_circle_outline(x_pos + size * 0.5, margin + size * 0.5, circle_size, 3, 64)
        render.SetScissorRect(0, 0, 0, 0, false)
      else

      end
    end

    return last_x + margin + size
  end

  return 0
end

function InfoDisplay:draw_all()
  if hook.run('PreDrawInfoDisplay', stored) == nil then
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
