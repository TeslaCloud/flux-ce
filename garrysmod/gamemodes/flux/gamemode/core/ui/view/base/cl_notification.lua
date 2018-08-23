local PANEL = {}
PANEL.lifetime = 6
PANEL.backgroundColor = Color(0, 0, 0)
PANEL.textColor = Color(255, 255, 255)

function PANEL:Init()
  self.curAlpha = 0
  self.creationTime = CurTime()
  self.notificationText = {"NOTIFICATION"}
  self.fontSize = 0
end

function PANEL:SizeToContents()
  local bX, bY = 0, -4

  for k, v in ipairs(self.notificationText) do
    local w, h = util.GetTextSize(v, theme.GetFont("Menu_Normal"))

    self.fontSize = h

    if (bX < w) then bX = w end

    bY = bY + h + 4
  end

  self:SetSize(bX + 8, bY + 8)
end

function PANEL:SetTextColor(col)
  self.textColor = col or Color(255, 255, 255)
end

function PANEL:SetBackgroundColor(col)
  self.backgroundColor = col or Color(0, 0, 0)
end

function PANEL:SetLifetime(time)
  timer.Simple(time, function()
    if (IsValid(self)) then
      self:SafeRemove()
    end
  end)

  self.lifetime = time
end

function PANEL:SetText(text)
  if (text:find("\n")) then
    text = string.Explode("\n", text)
  else
    text = {text}
  end

  self.notificationText = text

  self:SizeToContents()
end

function PANEL:Think()
  local curTime = CurTime()
  local frameTime = FrameTime() / 0.006

  if ((curTime - self.creationTime) > self.lifetime - 1.25) then
    self.curAlpha = self.curAlpha - 3 * frameTime
  elseif (self.curAlpha < 230) then
    self.curAlpha = self.curAlpha + 4 * frameTime
  end

  if (self.PostThink) then
    self:PostThink()
  end
end

function PANEL:Paint(width, height)
  if (!theme.Hook("PaintNotificationContainer", self, width, height)) then
    draw.RoundedBox(0, 0, 0, width, height, ColorAlpha(self.backgroundColor, self.curAlpha))
  end

  if (!theme.Hook("PaintNotificationText", self, width, height)) then
    local curY = 4

    for k, v in ipairs(self.notificationText) do
      draw.SimpleText(v, theme.GetFont("Menu_Normal"), 4, curY, ColorAlpha(self.textColor, self.curAlpha + 40))

      curY = curY + self.fontSize + 4
    end
  end
end

vgui.register("flNotification", PANEL, "EditablePanel")
