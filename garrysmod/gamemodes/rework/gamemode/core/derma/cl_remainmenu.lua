--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local PANEL = {};

function PANEL:Init()
	theme.Hook("CreateMainMenu", self);
end;

function PANEL:Paint(w, h)
	if (!theme.Hook("DrawMainMenu", self)) then
		surface.SetDrawColor(Color(0, 0, 0));
		surface.DrawRect(0, 0, w, h);
	end;
end;

function PANEL:Think()
	theme.Hook("MainMenuThink", self);
end;

vgui.Register("reMainMenu", PANEL, "EditablePanel");

concommand.Add("rwFactoryTest", function()
	local frame = vgui.Create("reFrame");
	frame:SetSize(600, 400);
	frame:SetPos(100, 100);

	local btn = vgui.Create("reButton", frame);
	btn:SetPos(1, 24);
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