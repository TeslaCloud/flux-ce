--- Client hooks of the SrcdsProxy plugin: show the countdown of a server transfer area on
-- the HUD of the local player while it runs.

--- Color of the countdown text.
local countdown_color = Color(255, 255, 255)

--- Seconds the text of a move that has been sent stays on the HUD after the countdown has
-- ended. When the proxy refuses the move, the player stays on this server, and the text goes
-- away after this time or once they leave the area, whichever comes first.
local moving_time = 10

--- Draws the countdown of the transfer area the local player is in, if one runs: the server
-- they are about to be moved to and the seconds that are left. Once it has ended the server
-- the player is being moved to is shown, for at most `moving_time` seconds.
-- @param cur_time [Number CurTime() of the frame]
-- @param scrw [Number screen width]
function SrcdsProxy:HUDPaintAlive(cur_time, scrw)
  local countdown = self.area_countdown

  if !countdown then return end

  if cur_time > countdown.end_time + moving_time then
    self.area_countdown = nil

    return
  end

  local seconds = math.ceil(countdown.end_time - cur_time)
  local text

  if seconds > 0 then
    text = t('ui.proxy.area_countdown', { server = countdown.backend, seconds = seconds })
  else
    text = t('ui.proxy.area_moving', { server = countdown.backend })
  end

  local font = Theme.get_font('text_normal_large')

  draw.SimpleText(text, font, scrw * 0.5, math.scale(120), countdown_color, TEXT_ALIGN_CENTER)
end
