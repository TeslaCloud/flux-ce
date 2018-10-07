local queue = {}

function PLUGIN:PlayerEnteredTextArea(player, area, cur_time)
  table.insert(queue, { text = 'test test test', expiry = cur_time + 8 })
end

function PLUGIN:HUDPaint()
  for k, v in ipairs(queue) do
    if v.expiry <= CurTime() then
      queue[k] = nil
    else
      draw.SimpleText(v.text, theme.get_font('text_normal_large'), 48, ScrH() * 0.5, Color(255, 255, 255))
    end
  end
end
