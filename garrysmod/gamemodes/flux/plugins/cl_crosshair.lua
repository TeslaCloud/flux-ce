PLUGIN:set_name('Crosshair')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds a crosshair.')

--fl.hint:Add('RunCrosshair', 'Crosshair will change it's size depending on your movement speed\nand distance between you and your view target.')

local size = 2
local half_size = size * 0.5
local gap = 8
local cur_gap = gap

function PLUGIN:HUDPaint()
  if hook.run('ShouldHUDPaint') != false then
    local trace = fl.client:GetEyeTraceNoCursor()
    local distance = fl.client:GetPos():Distance(trace.HitPos)
    local draw_color = plugin.call('AdjustCrosshairColor', trace, distance) or Color(255, 255, 255)
    local real_gap = plugin.call('AdjustCrosshairGap', trace, distance) or math.Round(gap * math.Clamp(distance / 400, 0.5, 4))
    cur_gap = Lerp(FrameTime() * 6, cur_gap, real_gap)

    if math.abs(cur_gap - real_gap) < 0.5 then
      cur_gap = real_gap
    end

    local scrw, scrh = ScrW(), ScrH()

    draw.RoundedBox(0, scrw * 0.5 - half_size, scrh * 0.5 - half_size, size, size, draw_color)

    draw.RoundedBox(0, scrw * 0.5 - half_size - cur_gap, scrh * 0.5 - half_size, size, size, draw_color)
    draw.RoundedBox(0, scrw * 0.5 - half_size + cur_gap, scrh * 0.5 - half_size, size, size, draw_color)

    draw.RoundedBox(0, scrw * 0.5 - half_size, scrh * 0.5 - half_size - cur_gap, size, size, draw_color)
    draw.RoundedBox(0, scrw * 0.5 - half_size, scrh * 0.5 - half_size + cur_gap, size, size, draw_color)
  end
end

function PLUGIN:AdjustCrosshairColor(trace, distance)
  local ent = trace.Entity

  if distance < 600 and IsValid(ent) and (ent:IsPlayer() or ent:GetClass() == 'fl_item') then
    return theme.get_color('accent')
  end
end

function PLUGIN:AdjustCrosshairGap(trace, distance)
  local ent = trace.Entity

  if distance < 600 and IsValid(ent) and (ent:IsPlayer() or ent:GetClass() == 'fl_item') then
    return 8
  end
end
