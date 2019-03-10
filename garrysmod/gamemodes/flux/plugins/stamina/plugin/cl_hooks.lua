local w, h = 256, 16
local cur_wide = w
local cur_alpha = 0

function Stamina:HUDPaint()
  local stamina = Flux.client:get_nv('stamina', 100)
  local frame_time = FrameTime() * 8
  local percentage = (stamina / config.get('stam_max', 100))

  if stamina < 98 then
    cur_alpha = Lerp(frame_time, cur_alpha, 1)
  else
    cur_alpha = Lerp(frame_time, cur_alpha, 0)
  end

  if Theme.hook('DrawStaminaBar', stamina, percentage, cur_alpha, frame_time) == nil then
    local cx, cy = ScrC()
    local x, y = cx - w * 0.5, cy - h * 0.5 + 100
    local cur_modifier = 255 * -(percentage - 1)
    cur_wide = Lerp(frame_time, cur_wide, w * percentage)

    draw.textured_rect(Theme.get_material('gradient'), x - 2, y - 2, w + 4, h + 4, Color(0, 0, 0, 160 * cur_alpha))
    draw.RoundedBox(0, x, y, cur_wide, h, Color(255 - cur_modifier * 0.25, 255 - cur_modifier * 0.75, 255 * percentage, 175 * cur_alpha))
  end
end
