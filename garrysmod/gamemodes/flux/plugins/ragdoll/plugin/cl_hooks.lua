fl.bars:register('getup', {
  text = t'bar_text.getup',
  color = Color(50, 200, 50),
  max_value = 100,
  x = ScrW() * 0.5 - fl.bars.defaultW * 0.5,
  y = ScrH() * 0.5 - 8,
  text_offset = 1,
  height = 20,
  type = BAR_MANUAL
})

function PLUGIN:PlayerBindPress(player, bind, pressed)
  if pressed and bind:find('jump') and player:IsDoingAction('fallen') then
    fl.command:Send('getup')
  end
end

function PLUGIN:HUDPaint()
  local fallen, getup = fl.client:IsDoingAction('fallen'), fl.client:IsDoingAction('getup')

  if (fallen or getup) and plugin.call('ShouldFallenHUDPaint') != false then
    local scrw, scrh = ScrW(), ScrH()

    draw.RoundedBox(0, 0, 0, scrw, scrh, Color(0, 0, 0, 100))

    if getup then
      local bar_value = 100 - 100 * ((fl.client:get_nv('getup_end', 0) - CurTime()) / fl.client:get_nv('getup_time'))

      fl.bars:SetValue('getup', bar_value)
      fl.bars:Draw('getup')
    elseif fallen then
      local text = t'press_jump_to_getup'
      local w, h = util.text_size(text, theme.get_font('text_normal'))

      draw.SimpleText(text, theme.get_font('text_normal'), scrw * 0.5 - w * 0.5, scrh * 0.5 - h * 0.5, theme.get_color('text'))
    end
  end
end
