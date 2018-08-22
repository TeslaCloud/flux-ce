--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]library.New("notification", fl)

local display = {}
local top = 1
local lastReposition = CurTime()

function fl.notification:Add(text, lifetime, textColor, backColor)
  local scrW = ScrW()
  lifetime = lifetime or 8
  text = fl.lang:TranslateText(text) or ""

  display[top] = {text = text, lifetime = lifetime, panel = nil, width = 0, height = 0, isLast = true}

  if (display[top - 1]) then
    display[top - 1].isLast = false
  end

  local panel = vgui.Create("flNotification")
  panel:SetText(text)
  panel:SetLifetime(lifetime)
  panel:SetTextColor(textColor)
  panel:SetBackgroundColor(backColor)

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
end

function fl.notification:AddPopup(text, lifetime, x, y, textColor, backColor)
  local panel = vgui.Create("flNotification")
  panel:SetPos(x, y)
  panel:SetText(text)
  panel:SetLifetime(lifetime)
  panel:SetTextColor(textColor)
  panel:SetBackgroundColor(backColor)

  function panel:PostThink()
    self:MoveToFront()
  end
end

function fl.notification:Reposition(offset)
  if (!isnumber(offset)) then return end

  local curTime = CurTime()

  if (lastReposition + 0.3 < curTime) then
    for k, v in ipairs(display) do
      if (v and IsValid(v.panel)) then
        local x, y = v.panel:GetPos()

        v.panel:MoveTo(x, y + offset + 4, 0.13)
      end
    end

    lastReposition = curTime
  else
    timer.Simple(0.3 - (curTime - lastReposition), function()
      self:Reposition()
    end)
  end
end
