library.new('notification', fl)

local display = {}
local top = 1
local queue = {}
local queue_locked = false

function fl.notification:process_queue()
  local notification = queue[1]

  if !queue_locked and notification then
    queue_locked = true

    local text, lifetime = notification.text, notification.lifetime
    local scrW = ScrW()
    lifetime = lifetime or 8
    text = t(text) or ''

    display[top] = {text = text, lifetime = lifetime, panel = nil, width = 0, height = 0, isLast = true}

    if display[top - 1] then
      display[top - 1].isLast = false
    end

    local panel = vgui.Create('fl_notification')
    panel:SetText(text)
    panel:SetLifetime(lifetime)
    panel:SetTextColor(notification.text_color)
    panel:SetBackgroundColor(notification.back_color)

    local w, h = panel:GetSize()
    panel:SetPos(scrW - w - 8, -h)
    panel:MoveTo(scrW - w - 8, 8, 0.13)

    display[top].panel = panel
    display[top].width = w
    display[top].height = h

    timer.Simple(lifetime, function()
      display[top] = nil
    end)

    top = top + 1

    self:Reposition(h)

    table.remove(queue, 1)

    timer.Simple(0.3, function() queue_locked = false fl.notification:process_queue() end)
  end
end

function fl.notification:Add(text, lifetime, text_color, back_color)
  table.insert(queue, { text = text, lifetime = lifetime, text_color = text_color, back_color = back_color })
  self:process_queue()
end

function fl.notification:AddPopup(text, lifetime, x, y, text_color, back_color)
  local panel = vgui.Create('fl_notification')
  panel:SetPos(x, y)
  panel:SetText(text)
  panel:SetLifetime(lifetime)
  panel:SetTextColor(text_color)
  panel:SetBackgroundColor(back_color)

  function panel:PostThink()
    self:MoveToFront()
  end
end

function fl.notification:Reposition(offset)
  if !isnumber(offset) then return end

  for k, v in ipairs(display) do
    if v and IsValid(v.panel) then
      local x, y = v.panel:GetPos()

      v.panel:MoveTo(x, y + offset + 4, 0.13)
    end
  end
end
