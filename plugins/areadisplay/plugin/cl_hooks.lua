--- Client side of the Area Display plugin: queues a notice when the local player enters a
-- text area and draws the queued notices on the HUD.

local queue = {}

--- Draws the queued text area notices at the left side of the screen
-- and drops the ones that have expired.
function PLUGIN:HUDPaint()
  for k, v in ipairs(queue) do
    if v.expiry <= CurTime() then
      queue[k] = nil
    else
      draw.SimpleText(v.text, Theme.get_font('text_normal_large'), 48, ScrH() * 0.5, Color(255, 255, 255))
    end
  end
end

--- Queues a notice to be displayed on the HUD for 8 seconds.
-- The displayed text is currently a hardcoded placeholder.
-- @param actor [Player the player who entered the area]
-- @param area [Map the area that was entered]
-- @param cur_time [Number CurTime at the moment of entering]
function PLUGIN:PlayerEnteredTextArea(actor, area, cur_time)
  table.insert(queue, { text = 'test test test', expiry = cur_time + 8 })
end
