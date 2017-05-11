--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

--[[
	Simplistic base panel that has basic colors, fields and methods commonly used throughout Flux Framework.
	Do not use it directly, base your own panels off of it instead.
--]]

local PANEL = {}
PANEL.m_BackgroundColor = Color(0, 0, 0)
PANEL.m_TextColor = Color(255, 255, 255)
PANEL.m_MainColor = Color(255, 100, 100)
PANEL.m_AccentColor = Color(200, 200, 200)
PANEL.m_DrawBackground = true
PANEL.m_Title = "Flux Base Panel"
PANEL.m_Font = "fl_frame_title"

AccessorFunc(PANEL, "m_DrawBackground", "DrawBackground")
AccessorFunc(PANEL, "m_BackgroundColor", "BackgroundColor")
AccessorFunc(PANEL, "m_Title", "Title")
AccessorFunc(PANEL, "m_Font", "Font")
AccessorFunc(PANEL, "m_MainColor", "MainColor")
AccessorFunc(PANEL, "m_TextColor", "TextColor")
AccessorFunc(PANEL, "m_AccentColor", "AccentColor")

function PANEL:Paint(width, height) theme.Hook("PaintPanel", self, width, height) end
function PANEL:Think() theme.Hook("PanelThink", self) end

-- MVC Functionality for all FL panels.
function PANEL:Push(strName, ...)
	mvc.Push(strName, ...)
end

function PANEL:Pull(strName, handler, bPreventRemove)
	mvc.Pull(strName, handler, bPreventRemove)
end

function PANEL:Request(strName, handler, ...)
	self:Pull(strName, handler)
	self:Push(strName, ...)
end

vgui.Register("flBasePanel", PANEL, "EditablePanel")