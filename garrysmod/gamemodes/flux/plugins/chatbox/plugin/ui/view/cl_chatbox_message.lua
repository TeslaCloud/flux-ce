--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local PANEL = {}
PANEL.messageData = {}
PANEL.compiled = {}
PANEL.addTime = 0
PANEL.forceShow = false
PANEL.forceAlpha = false
PANEL.shouldPaint = false
PANEL.alpha = 255

function PANEL:Init()
  --if (fl.client:HasPermission("chat_mod")) then
  --  self.moderation = vgui.Create("flChatModeration", self)
  --end

  self.addTime = CurTime()
  self.fadeTime = self.addTime + config.Get("chatbox_message_fade_delay")
end

function PANEL:Think()
  local curTime = CurTime()

  self.shouldPaint = false

  if (chatbox.panel:IsTypingCommand()) then
    self.forceAlpha = 50
  else
    self.forceAlpha = false
  end

  if (self.forceShow) then
    self.shouldPaint = true

    if (self.forceAlpha) then
      self.alpha = self.forceAlpha
    else
      self.alpha = 255
    end
  elseif (self.fadeTime > curTime) then
    self.shouldPaint = true

    local diff = self.fadeTime - curTime

    if (diff < 1) then
      self.alpha = Lerp(FrameTime() * 6, self.alpha, 0)
    end
  else
    self.alpha = 0
  end
end

function PANEL:SetMessage(msgInfo)
  self.messageData = msgInfo

  self:SetSize(self:GetWide(), msgInfo.totalHeight)
end

-- Those people want us gone :(
function PANEL:Eject()
  if (plugin.call("ShouldMessageEject", self) != false) then
    local parent = chatbox.panel

    if (!IsValid(parent)) then return end

    parent:RemoveMessage(self.messageIndex or 1)
    parent:Rebuild()

    self:SafeRemove()
  end
end

function PANEL:Paint(w, h)
  if (self.shouldPaint) then
    if (plugin.call("ChatboxPrePaintMessage", w, h, self) == true) then return end

    local curColor = Color(255, 255, 255, self.alpha)
    local curFont = font.GetSize(theme.GetFont("Chatbox_Normal"), font.Scale(20))

    for k, v in ipairs(self.messageData) do
      if (istable(v)) then
        if (v.text) then
          draw.SimpleText(v.text, curFont, v.x, v.y, curColor)
        elseif (IsColor(v)) then
          curColor = ColorAlpha(v, self.alpha)
        elseif (v.image) then
          draw.TexturedRect(util.GetMaterial(v.image), v.x, v.y, v.w, v.h, Color(255, 255, 255, self.alpha))
        end
      elseif (isnumber(v)) then
        curFont = font.GetSize(theme.GetFont("Chatbox_Normal"), v)
      end
    end
  end
end

vgui.Register("flChatMessage", PANEL, "flBasePanel")
