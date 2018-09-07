local queue = {}

function PLUGIN:PlayerEnteredTextArea(player, area, curTime)
  table.insert(queue, {text = "test test test", expiry = curTime + 8})
end

function PLUGIN:HUDPaint()
  for k, v in ipairs(queue) do
    if v.expiry <= CurTime() then
      queue[k] = nil
    else
      draw.SimpleText(v.text, theme.GetFont("Text_NormalLarge"), 48, ScrH() * 0.5, Color(255, 255, 255))
    end
  end
end
