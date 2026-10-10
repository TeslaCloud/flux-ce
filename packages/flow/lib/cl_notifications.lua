--- On-screen notifications: short messages that slide in at the top right corner of the
-- screen. `Flux.Notification:add` queues a message, either plain text or a language phrase.
-- Queued messages are displayed one after another as `fl_notification` panels, each one
-- pushing the older ones down, and disappear after their lifetime.
-- `Flux.Notification:add_popup` creates a single notification at a given position instead. On
-- the client `Player:notify` displays its message through this library; server code sends
-- notifications with `Player:notify` or `Flux.Player:notify`.

mod 'Flux::Notification'

local display = {}
local top = 1
local queue = {}
local queue_locked = false

--- Displays the next queued notification in the top right corner of the screen and pushes
-- the older ones down. Does nothing while another notification is still sliding in.
function Flux.Notification:process_queue()
  local notification = queue[1]

  if !queue_locked and notification then
    queue_locked = true

    local text, lifetime = notification.text, notification.lifetime
    local scrw = ScrW()
    lifetime = lifetime or 8
    text = t(text) or ''

    local entry = { text = text, lifetime = lifetime, panel = nil, width = 0, height = 0, is_last = true }
    local previous = display[top - 1]

    display[top] = entry

    if previous then
      previous.is_last = false
    end

    local panel = vgui.Create('fl_notification')
    panel:set_text(text)
    panel:set_lifetime(lifetime)
    panel:set_text_color(notification.text_color)
    panel:set_background_color(notification.back_color)

    local w, h = panel:GetSize()
    local x = scrw - w - 8
    panel:SetPos(x, -h)
    panel:MoveTo(x, 8, 0.1)

    entry.panel = panel
    entry.width = w
    entry.height = h

    timer.Simple(lifetime, function()
      display[top] = nil
    end)

    top = top + 1

    self:reposition(h)

    table.remove(queue, 1)

    timer.Simple(0.25, function()
      queue_locked = false
      Flux.Notification:process_queue()
    end)
  end
end

--- Queues a notification to be displayed in the top right corner of the screen.
-- @param text [String text or language phrase]
-- @param lifetime=8 [Number how long to display it for, in seconds]
-- @param text_color=Color(255, 255, 255) [Color]
-- @param back_color=Color(0, 0, 0) [Color]
function Flux.Notification:add(text, lifetime, text_color, back_color)
  queue[#queue + 1] = { text = text, lifetime = lifetime, text_color = text_color, back_color = back_color }
  self:process_queue()
end

--- Immediately creates a notification at the specified position, bypassing the queue.
-- The text is displayed as is, without being translated.
-- @param text [String]
-- @param lifetime [Number how long to display it for, in seconds]
-- @param x [Number]
-- @param y [Number]
-- @param text_color=Color(255, 255, 255) [Color]
-- @param back_color=Color(0, 0, 0) [Color]
function Flux.Notification:add_popup(text, lifetime, x, y, text_color, back_color)
  local panel = vgui.Create('fl_notification')
  panel:SetPos(x, y)
  panel:set_text(text)
  panel:set_lifetime(lifetime)
  panel:set_text_color(text_color)
  panel:set_background_color(back_color)

  --- Keeps the popup notification above all other panels.
  function panel:PostThink()
    self:MoveToFront()
  end
end

--- Moves all of the displayed notifications down to make room for a new one.
-- @param offset [Number height of the new notification in pixels]
function Flux.Notification:reposition(offset)
  if !isnumber(offset) then return end

  local shift = offset + 4

  for k, v in ipairs(display) do
    local panel = v.panel

    if IsValid(panel) then
      local x, y = panel:GetPos()

      panel:MoveTo(x, y + shift, 0.1)
    end
  end
end
