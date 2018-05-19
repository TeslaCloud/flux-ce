--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local PANEL = {}
PANEL.m_CurAmt = 160

function PANEL:Init()
  self.Image = vgui.Create("DImage", self)
  self.Image:SetSize(100, 100)
  self.Image:SetPos(0, 0)
end

function PANEL:SetImage(img)
  self.Image:SetImage(img)
end

function PANEL:Paint(w, h) end

function PANEL:PaintOver(w, h)
  local active = self.m_Active

  draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, (!active and self.m_CurAmt * 4) or 0))

  if (active) then
    surface.SetDrawColor(theme.GetColor("Accent"))
    surface.DrawOutlinedRect(0, 0, w, h)
  end
end

function PANEL:Think()
  if (self:IsHovered()) then
    self.m_CurAmt = math.Clamp(self.m_CurAmt - 1, 0, 40)
  else
    self.m_CurAmt = math.Clamp(self.m_CurAmt + 1, 0, 40)
  end

  self.Image:SetSize(self:GetWide(), self:GetTall())
end

vgui.Register("flImageButton", PANEL, "flButton")
