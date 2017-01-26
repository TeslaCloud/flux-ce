--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local PANEL = {};

function PANEL:Init()
	self:SetTitle("Rework Frame");
	self:SetMainColor(Color(55, 55, 55, 235));
	self:SetAccentColor(Color(90, 90, 190));

	self.btnClose = vgui.Create("reButton", self);
	self.btnClose:SetSize(20, 20);
	self.btnClose:SetPos(0, 0);
	self.btnClose:SetIcon("fa-times");
	self.btnClose:SetText("");
	self.btnClose:SetDrawBackground(false);
	self.btnClose.DoClick = function(button)
		self:SetVisible(false);
		self:Remove();
	end;
end;

function PANEL:Paint(w, h)
	if (!theme.Hook("PaintFrame", self, w, h)) then
		surface.SetDrawColor(self:GetAccentColor());
		surface.DrawOutlinedRect(0, 0, w, h);
		surface.DrawRect(1, 1, w - 2, 20);

		surface.SetDrawColor(self.m_MainColor);
		surface.DrawRect(1, 20, w - 2, h - 21);

		local title = self:GetTitle();

		if (title) then
			draw.SimpleText(title, "rw_frame_title", 6, 4, self:GetTextColor());
		end;
	end;
end;

function PANEL:Think()
	local w, h = self:GetSize();

	if (IsValid(self.btnClose)) then
		self.btnClose:SetPos(w - 20, 0);
	end;
end;

vgui.Register("reFrame", PANEL, "rwBasePanel");