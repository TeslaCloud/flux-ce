--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local PANEL = {};

PANEL.mainColor = Color(240, 240, 240);
PANEL.accentColor = Color(60, 60, 155);
PANEL.m_Title = "Rework Frame";

function PANEL:Init()
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
	if (!theme.Hook("DrawFrame", self)) then
		surface.SetDrawColor(self.accentColor);
		surface.DrawRect(0, 0, w, h);

		surface.SetDrawColor(self.mainColor);
		surface.DrawRect(1, 20, w - 2, h - 21);

		if (self.m_Title and self.m_Title != "") then
			draw.SimpleText(self.m_Title, "rw_frame_title", 6, 4, Color(255, 255, 255));
		end;
	end;
end;

function PANEL:Think()
	local w, h = self:GetSize();

	if (IsValid(self.btnClose)) then
		self.btnClose:SetPos(w - 20, 0);
	end;
end;

function PANEL:SetTitle(newTitle)
	if (newTitle) then
		self.m_Title = tostring(newTitle);
	else
		self.m_Title = "Rework Frame";
	end;
end;

function PANEL:SetMainColor(newColor)
	newColor = newColor or Color(240, 240, 240);

	self.mainColor = newColor;
end;

function PANEL:SetAccentColor(newColor)
	newColor = newColor or Color(240, 240, 240);

	self.accentColor = newColor;
end;

vgui.Register("reFrame", PANEL, "EditablePanel");

concommand.Add("rwFactoryTest", function()
	local frame = vgui.Create("reFrame");
	frame:SetSize(600, 400);
	frame:SetPos(100, 100);

	local btn = vgui.Create("reButton", frame);
	btn:SetPos(0, 24);
	btn:SetText("Some Button");
	btn.DoClick = function(button)
		print("button click");
	end;
	local font = rw.fonts:GetSize("rw_frame_title", 16)
	btn:SetFont(font);
	btn:SetIcon("fa-cog")
	btn:SizeToContents();

	frame:MakePopup();
end);