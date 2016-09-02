--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

-- todo finish the panel lol

local PANEL = {};

function PANEL:Init()
	self:SetSize(ScrW(), ScrH());
	self:SetPos(0, 0);
end;

vgui.Register("reMainMenu", PANEL, "DFrame");