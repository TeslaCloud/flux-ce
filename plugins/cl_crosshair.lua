PLUGIN:set_name('Crosshair')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds a crosshair.')

--Flux.hint:Add('RunCrosshair', 'Crosshair will change it's size depending on your movement speed\nand distance between you and your view target.')

local size = 2
local half_size = size * 0.5
local double_size = size * 2
local gap = 8
local cur_gap = gap

function PLUGIN:ShouldHUDPaintCrosshair()
  if PLAYER:running() or !PLAYER:Alive() or !PLAYER:has_initialized() then
    return false
  end
end

function PLUGIN:HUDPaint()
  if IsValid(PLAYER) and hook.run('ShouldHUDPaint') != false and hook.run('ShouldHUDPaintCrosshair') != false then
    local lerp_step = FrameTime() * 6
    local trace = PLAYER:GetEyeTraceNoCursor()
    local distance = PLAYER:GetPos():Distance(trace.HitPos)
    local draw_color = Plugin.call('AdjustCrosshairColor', trace, distance) or color_white
    local secondary_draw_color = draw_color:alpha(25)
    local real_gap = Plugin.call('AdjustCrosshairGap', trace, distance) or math.Round(gap * math.Clamp(distance / 400, 0.5, 4))
    cur_gap = Lerp(lerp_step, cur_gap, real_gap)

    if math.abs(cur_gap - real_gap) < 0.5 then
      cur_gap = real_gap
    end

    if draw_color != color_white then
      secondary_draw_color = secondary_draw_color:alpha(255)
    end

    local scrw, scrh = ScrW(), ScrH()
    local gox, goy = Flux.global_ui_offset()

    draw.RoundedBox(0, gox + (scrw * 0.5 - half_size), goy + (scrh * 0.5 - half_size), size, size, draw_color)

    draw.RoundedBox(0, gox + (scrw * 0.5 - half_size - cur_gap), goy + (scrh * 0.5 - size), size, double_size, secondary_draw_color)
    draw.RoundedBox(0, gox + (scrw * 0.5 - half_size + cur_gap), goy + (scrh * 0.5 - size), size, double_size, secondary_draw_color)

    draw.RoundedBox(0, gox + (scrw * 0.5 - size), goy + (scrh * 0.5 - half_size - cur_gap), double_size, size, secondary_draw_color)
    draw.RoundedBox(0, gox + (scrw * 0.5 - size), goy + (scrh * 0.5 - half_size + cur_gap), double_size, size, secondary_draw_color)
  end
end

function PLUGIN:AdjustCrosshairColor(trace, distance)
  local ent = trace.Entity

  if distance < 600 and IsValid(ent) and (ent:IsPlayer() or ent:GetClass() == 'fl_item') then
    return Theme.get_color('accent')
  end
end

function PLUGIN:AdjustCrosshairGap(trace, distance)
  local ent = trace.Entity

  if distance < 600 and IsValid(ent) and (ent:IsPlayer() or ent:GetClass() == 'fl_item') then
    return 8
  end
end
