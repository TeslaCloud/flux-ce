local PANEL = {}
PANEL.categories = {}

function PANEL:Init()
  self.html = vgui.Create('fl_html', self)
  self.html:Dock(FILL)
  self:Rebuild()
end

function PANEL:Rebuild()
  self.html:set_css(render_stylesheet('help'))
  self.html:set_body(render_template('help'))
  self.html:render()
end

function PANEL:GetMenuSize()
  return font.Scale(1280), font.Scale(900)
end

vgui.Register('fl_help', PANEL, 'fl_base_panel')
