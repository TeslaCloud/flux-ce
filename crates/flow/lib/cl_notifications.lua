library 'Flux::Notification'

local display = {}
local top = 1
local queue = {}
local queue_locked = false

function Flux.Notification:process_queue()
  local notification = queue[1]

  if !queue_locked and notification then
    queue_locked = true

    local text, lifetime = notification.text, notification.lifetime
    local scrw = ScrW()
    lifetime = lifetime or 8
    text = t(text) or ''

    display[top] = { text = text, lifetime = lifetime, panel = nil, width = 0, height = 0, is_last = true }

    if display[top - 1] then
      display[top - 1].is_last = false
    end

    local panel = vgui.Create('fl_notification')
    panel:set_text(text)
    panel:set_lifetime(lifetime)
    panel:set_text_color(notification.text_color)
    panel:set_background_color(notification.back_color)

    local w, h = panel:GetSize()
    panel:SetPos(scrw - w - 8, -h)
    panel:MoveTo(scrw - w - 8, 8, 0.1)

    display[top].panel = panel
    display[top].width = w
    display[top].height = h

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

function Flux.Notification:add(text, lifetime, text_color, back_color)
  table.insert(queue, { text = text, lifetime = lifetime, text_color = text_color, back_color = back_color })
  self:process_queue()
end

function Flux.Notification:add_popup(text, lifetime, x, y, text_color, back_color)
  local panel = vgui.Create('fl_notification')
  panel:SetPos(x, y)
  panel:set_text(text)
  panel:set_lifetime(lifetime)
  panel:set_text_color(text_color)
  panel:set_background_color(back_color)

  function panel:PostThink()
    self:MoveToFront()
  end
end

function Flux.Notification:reposition(offset)
  if !isnumber(offset) then return end

  for k, v in ipairs(display) do
    if v and IsValid(v.panel) then
      local x, y = v.panel:GetPos()

      v.panel:MoveTo(x, y + offset + 4, 0.1)
    end
  end
end
