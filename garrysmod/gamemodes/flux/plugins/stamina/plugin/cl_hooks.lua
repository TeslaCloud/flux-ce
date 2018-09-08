local w, h = 256, 24
local cur_wide = w
local cur_alpha = 0

function Stamina:HUDPaint()
  local stamina = fl.client:get_nv('stamina', 100)
  local frame_time = FrameTime() * 8
  local percentage = (stamina / 100)

  if stamina < 98 then
    cur_alpha = Lerp(frame_time, cur_alpha, 1)
  else
    cur_alpha = Lerp(frame_time, cur_alpha, 0)
  end

  if theme.Hook('DrawStaminaBar', stamina, percentage, cur_alpha, frame_time) == nil then
    local cx, cy = ScrC()
    local x, y = cx - w * 0.5, cy - h * 0.5 + 100
    cur_wide = Lerp(frame_time, cur_wide, w * percentage)

    draw.RoundedBox(0, x, y, w, h, Color(40, 40, 40, 100 * cur_alpha))
    draw.RoundedBox(0, x, y, cur_wide, h, Color(255, 255, 255, 200 * cur_alpha))
  end
end
