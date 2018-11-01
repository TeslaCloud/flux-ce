--[[
  Simplistic base panel that has basic colors, fields and methods commonly used throughout Flux Framework.
  Do not use it directly, base your own panels off of it instead.
--]]

local PANEL = {}
PANEL.draw_background = true
PANEL.background_color = Color(0, 0, 0)
PANEL.text_color = Color(255, 255, 255)
PANEL.main_color = Color(255, 100, 100)
PANEL.accent_color = Color(200, 200, 200)
PANEL.title = 'Flux Base Panel'
PANEL.font = theme.get_font('menu_titles') or 'flRoboto'

AccessorFunc(PANEL, 'draw_background', 'DrawBackground')
AccessorFunc(PANEL, 'background_color', 'BackgroundColor')
AccessorFunc(PANEL, 'text_color', 'TextColor')
AccessorFunc(PANEL, 'main_color', 'MainColor')
AccessorFunc(PANEL, 'accent_color', 'AccentColor')
AccessorFunc(PANEL, 'title', 'Title')
AccessorFunc(PANEL, 'font', 'Font')

function PANEL:Paint(width, height)
  theme.hook('PaintPanel', self, width, height)
end

function PANEL:Think() theme.hook('PanelThink', self)
end

-- MVC Functionality for all FL panels.
function PANEL:push(name, ...)
  mvc.push(name, ...)
end

function PANEL:pull(name, handler, prevent_remove)
  mvc.pull(name, handler, prevent_remove)
end

function PANEL:request(name, handler, ...)
  self:pull(name, handler)
  self:push(name, ...)
end

vgui.Register('fl_base_panel', PANEL, 'EditablePanel')
