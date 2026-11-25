--- On-screen notifications: short messages that slide in at the top right corner of the
-- screen. `Flux.Notification:add` queues a message, either plain text or a language phrase.
-- Queued messages are displayed one after another as `fl_notification` panels, the newest at
-- the top, and disappear after their lifetime. At most six are on the screen at a time: the
-- oldest one leaves early to make room for the next one, and the others move up into the place
-- of one that leaves. `Flux.Notification:add_popup` creates a single notification at a given
-- position instead. On the client `Player:notify` displays its message through this library;
-- server code sends notifications with `Player:notify` or `Flux.Player:notify`.

mod 'Flux::Notification'

local display = {}
local queue = {}
local queue_locked = false
local max_displayed = 6

--- Takes the notifications that are leaving or have been removed off the stack.
local function prune_display()
  for index = #display, 1, -1 do
    local panel = display[index]

    if !IsValid(panel) or panel.leaving then
      table.remove(display, index)
    end
  end
end

--- Displays the next queued notification at the top right corner of the screen, below which
-- the older ones are stacked, and makes the oldest one leave if there are more than six. Does
-- nothing while another notification is still sliding in.
function Flux.Notification:process_queue()
  local notification = queue[1]

  if !queue_locked and notification then
    queue_locked = true

    local text, lifetime = notification.text, notification.lifetime
    lifetime = lifetime or 8
    text = t(text) or ''

    local panel = vgui.Create('fl_notification')
    panel:set_text(text)
    panel:set_lifetime(lifetime)
    panel:set_text_color(notification.text_color)
    panel:set_background_color(notification.back_color)
    panel:SetPos(ScrW() - panel:GetWide() - math.scale(12), -panel:GetTall())

    display[#display + 1] = panel

    table.remove(queue, 1)
    prune_display()

    if #display > max_displayed then
      display[1]:dismiss()
    else
      self:reposition()
    end

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

--- Stacks the displayed notifications from the top right corner of the screen down, the
-- newest at the top, and moves each one to its place. Notifications that are leaving or have
-- been removed are taken off the stack first, so that the others close the gap.
function Flux.Notification:reposition()
  local margin = math.scale(12)
  local gap = math.scale(6)
  local scrw = ScrW()
  local y = margin

  prune_display()

  for index = #display, 1, -1 do
    local panel = display[index]

    panel:MoveTo(scrw - panel:GetWide() - margin, y, 0.15)

    y += panel:GetTall() + gap
  end
end
