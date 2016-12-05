--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local PANEL = {};

PANEL.m_MainColor = Color(45, 45, 45);
PANEL.m_AccentColor = Color(0, 0, 0);
PANEL.m_TextColor = Color(255, 255, 255);
PANEL.m_Text = "Rework Frame";
PANEL.m_Font = "rw_frame_title";
PANEL.m_bDrawBackground = true;
PANEL.m_Icon = false;

function PANEL:Paint(w, h)
	if (!theme.Hook("DrawButton", self)) then
		if (self.m_bDrawBackground) then
			surface.SetDrawColor(self.m_AccentColor);
			surface.DrawRect(0, 0, w, h);

			if (!self:IsHovered()) then
				surface.SetDrawColor(self.m_MainColor);
			else
				surface.SetDrawColor(self.m_MainColor:Lighten(40));
			end;

			surface.DrawRect(1, 1, w - 2, h - 2);
		end;

		local textColor = self.m_TextColor;
		local oX = 0;

		if (self:IsHovered()) then
			textColor = textColor:Darken(40);
		end;

		if (self.m_Icon) then
			oX = h / 2 - 4;

			rw.fa:Draw(self.m_Icon, 3, 3, h - 6, textColor);
		end;

		if (self.m_Text and self.m_Text != "") then
			local width, height = util.GetTextSize(self.m_Text, self.m_Font);
			draw.SimpleText(self.m_Text, self.m_Font, w / 2 - width / 2 - 1 + oX, h / 2 - height / 2, textColor);
		end;
	end;
end;

function PANEL:SetTextColor(newColor, g, b, a)
	if (typeof(newColor) == "number") then
		self.m_TextColor = Color(newColor or 255, g or 255, b or 255, a or 255);
	else
		self.m_TextColor = newColor or Color(255, 255, 255);
	end;
end;

function PANEL:SetText(newText)
	if (newText) then
		self.m_Text = tostring(newText);
	else
		self.m_Text = "Button";
	end;
end;

function PANEL:SetDrawBackground(bDrawBackground)
	self.m_bDrawBackground = bDrawBackground;
end;

function PANEL:SetFont(newFont)
	self.m_Font = tostring(newFont) or "rw_frame_title";
end;

function PANEL:SetIcon(icon)
	self.m_Icon = tostring(icon) or false;
end;

function PANEL:OnMousePressed(key)
	if (key == MOUSE_LEFT) then
		if (self.DoClick) then
			self:DoClick();
		end;
	elseif (key == MOUSE_RIGHT) then
		if (self.DoRightClick) then
			self:DoRightClick();
		end
	end;
end;

function PANEL:SizeToContents()
	local w, h = util.GetTextSize(self.m_Text, self.m_Font);
	local add = 0;

	if (self.m_Icon) then
		add = h * 1.5 - 2;
	end;

	self:SetSize(w * 1.15 + add, h * 1.5);
end;

function PANEL:SetMainColor(newColor)
	newColor = newColor or Color(40, 40, 40);

	self.m_MainColor = newColor;
end;

function PANEL:SetAccentColor(newColor)
	newColor = newColor or Color(40, 40, 40);

	self.m_AccentColor = newColor;
end;

vgui.Register("reButton", PANEL, "EditablePanel");