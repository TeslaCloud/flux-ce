local PANEL = {};

local colorWhite = Color(255, 255, 255, 100);

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH();

	self:SetSize(scrW * 0.6, scrH * 0.6);
end;

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, colorWhite);
end;

derma.DefineControl("rwSettings", "", PANEL, "DPanel");