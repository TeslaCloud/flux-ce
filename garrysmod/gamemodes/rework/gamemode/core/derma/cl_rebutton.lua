--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local PANEL = {};

PANEL.m_Icon = false;
PANEL.m_Autopos = true;
PANEL.m_BackgroundColor = Color(50, 50, 50);
PANEL.m_MainColor = Color(60, 60, 60);
PANEL.m_CurAmt = 0;

function PANEL:Paint(w, h)
	if (!theme.Hook("PaintButton", self, w, h)) then
		local curAmt = self.m_CurAmt;

		if (self.m_DrawBackground) then
			surface.SetDrawColor(self.m_AccentColor);
			surface.DrawRect(0, 0, w, h);

			surface.SetDrawColor(self.m_MainColor:Lighten(curAmt));
			surface.DrawRect(1, 1, w - 2, h - 2);
		end;

		local textColor = self.m_TextColor:Darken(curAmt);

		if (self.m_Icon) then
			rw.fa:Draw(self.m_Icon, 3, 3, h - 6, textColor);
		end;

		if (self.m_Title and self.m_Title != "") then
			local width, height = util.GetTextSize(self.m_Title, self.m_Font);

			if (self.m_Autopos) then
				if (self.m_Icon) then
					draw.SimpleText(self.m_Title, self.m_Font, h + 2, h / 2 - height / 2, textColor);
				else
					draw.SimpleText(self.m_Title, self.m_Font, w / 2 - width / 2, h / 2 - height / 2, textColor);
				end;
			else
				draw.SimpleText(self.m_Title, self.m_Font, 0, h / 2 - height / 2, textColor);
			end;
		end;
	end;
end;

function PANEL:Think()
	self.BaseClass.Think(self);

	if (self:IsHovered()) then
		self.m_CurAmt = math.Clamp(self.m_CurAmt + 1, 0, 40);
	else
		self.m_CurAmt = math.Clamp(self.m_CurAmt - 1, 0, 40);
	end;
end;

function PANEL:SetText(newText)
	return self:SetTitle(newText);
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

function PANEL:SetTextAutoposition(bAutoposition)
	self.m_Autopos = bAutoposition;
end;

function PANEL:SizeToContents()
	local w, h = util.GetTextSize(self.m_Title, self.m_Font);
	local add = 0;

	if (self.m_Icon) then
		add = h * 1.5 - 2;
	end;

	self:SetSize(w * 1.15 + add, h * 1.5);
end;

vgui.Register("rwButton", PANEL, "rwBasePanel");