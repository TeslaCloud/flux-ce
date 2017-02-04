--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local PANEL = {}

PANEL.m_Icon = false
PANEL.m_Autopos = true
PANEL.m_CurAmt = 0
PANEL.m_Active = false
PANEL.m_IconSize = nil

function PANEL:Paint(w, h)
	theme.Hook("PaintButton", self, w, h)
end

function PANEL:Think()
	self.BaseClass.Think(self)

	if (self:IsHovered()) then
		self.m_CurAmt = math.Clamp(self.m_CurAmt + 1, 0, 40)
	else
		self.m_CurAmt = math.Clamp(self.m_CurAmt - 1, 0, 40)
	end
end

function PANEL:SetActive(active)
	self.m_Active = active
end

function PANEL:SetText(newText)
	return self:SetTitle(newText)
end

function PANEL:SetIcon(icon)
	self.m_Icon = tostring(icon) or false
end

function PANEL:SetIconSize(size)
	self.m_IconSize = size
end

function PANEL:OnMousePressed(key)
	if (key == MOUSE_LEFT) then
		if (self.DoClick) then
			self:DoClick()
		end
	elseif (key == MOUSE_RIGHT) then
		if (self.DoRightClick) then
			self:DoRightClick()
		end
	end
end

function PANEL:SetTextAutoposition(bAutoposition)
	self.m_Autopos = bAutoposition
end

function PANEL:SizeToContents()
	local w, h = util.GetTextSize(self.m_Title, self.m_Font)
	local add = 0

	if (self.m_Icon) then
		add = h * 1.5 - 2
	end

	self:SetSize(w * 1.15 + add, h * 1.5)
end

vgui.Register("rwButton", PANEL, "rwBasePanel");