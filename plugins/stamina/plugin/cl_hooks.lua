local w, h = math.scale(512), math.scale(4)
local cur_wide = w
local cur_alpha = 0

function Stamina:HUDPaint()
  if IsValid(PLAYER) and PLAYER:Alive() then 
    local stamina = PLAYER:get_nv('stamina', 100)
    local frame_time = FrameTime() * 8
    local percentage = (stamina / Config.get('stam_max', 100))

    if stamina < 98 then
      cur_alpha = Lerp(frame_time, cur_alpha, 1)
    else
      cur_alpha = Lerp(frame_time, cur_alpha, 0)
    end

    if Theme.hook('DrawStaminaBar', stamina, percentage, cur_alpha, frame_time) == nil then
      local cx, cy = ScrC()
      local gx, gy = Flux.global_ui_offset()
      local x, y = gx + cx - w * 0.5, gy + cy - h * 0.5 + math.scale(300)

      cur_wide = Lerp(frame_time, cur_wide, w * percentage)

      draw.textured_rect(Theme.get_material('gradient'), x - 2, y - 2, w + 4, h + 4, Color(0, 0, 0, 160 * cur_alpha))
      draw.RoundedBox(0, x, y, cur_wide, h, LerpColor(1 - percentage, Color(0, 225, 0), Color(200, 0, 0)):alpha(200 * cur_alpha))
    end
  end
end
