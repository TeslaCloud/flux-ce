--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

--[[
	Simplistic base panel that has basic colors, fields and methods commonly used throughout Rework.
	Do not use it directly, base your own panels off of it instead.
--]]

local PANEL = {};
PANEL.m_BackgroundColor = Color(0, 0, 0);
PANEL.m_TextColor = Color(255, 255, 255);
PANEL.m_MainColor = Color(255, 100, 100);
PANEL.m_AccentColor = Color(200, 200, 200);
PANEL.m_DrawBackground = true;
PANEL.m_Title = "RW Base Panel";

function PANEL:SetDrawBackground(bDrawBackground)
	self.m_DrawBackground = bDrawBackground;
end;

function PANEL:SetBackgroundColor(color)
	self.m_BackgroundColor = color or Color(0, 0, 0);
end;

function PANEL:SetTitle(text)
	self.m_Title = text;
end;

function PANEL:SetMainColor(color)
	self.m_MainColor = color or Color(255, 100, 100);
end;

function PANEL:SetTextColor(color)
	self.m_TextColor = color or Color(255, 255, 255);
end;

function PANEL:SetAccentColor(color)
	self.m_AccentColor = color or Color(200, 200, 200);
end;

function PANEL:GetTitle()
	return (self.m_Title and self.m_Title != "" and self.m_Title) or nil;
end;

function PANEL:GetDrawBackground(bDrawBackground)
	return self.m_DrawBackground;
end;

function PANEL:GetBackgroundColor()
	return self.m_BackgroundColor;
end;

function PANEL:GetMainColor()
	return self.m_MainColor;
end;

function PANEL:GetTextColor()
	return self.m_TextColor;
end;

function PANEL:GetAccentColor()
	return self.m_AccentColor;
end;

function PANEL:Paint(width, height) end;
function PANEL:Think() end;

vgui.Register("rwBasePanel", PANEL, "EditablePanel");