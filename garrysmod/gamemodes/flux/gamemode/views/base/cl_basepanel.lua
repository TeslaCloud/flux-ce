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
PANEL.m_Font = theme.GetFont("MenuTitles") or "flRoboto"

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
function PANEL:Push(name, ...)
  mvc.push(name, ...)
end

function PANEL:Pull(name, handler, prevent_remove)
  mvc.pull(name, handler, prevent_remove)
end

function PANEL:Request(name, handler, ...)
  self:Pull(name, handler)
  self:Push(name, ...)
end

vgui.Register("fl_base_panel", PANEL, "EditablePanel")
