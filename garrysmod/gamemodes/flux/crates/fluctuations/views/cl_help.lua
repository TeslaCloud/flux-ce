local PANEL = {}
PANEL.categories = {}

function PANEL:Init()
  self.html = vgui.Create('fl_html', self)
  self.html:Dock(FILL)
  self:rebuild()
end

function PANEL:rebuild()
  self.html:set_css(render_stylesheet('help'))
  self.html:set_body(render_template('help'))
  self.html:set_javascript(render_javascript('help'))
  self.html:render()
end

function PANEL:get_menu_size()
  return Font.scale(1280), Font.scale(900)
end

vgui.Register('fl_help', PANEL, 'fl_base_panel')
