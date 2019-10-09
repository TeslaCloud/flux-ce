local PANEL = Gvue.new_panel()
PANEL.element_name = 'text'

function PANEL:draw(w, h)
  draw.SimpleText(
    self.html.inner_html,
    self.context.attributes.font_family,
    0,
    0,
    self.context.attributes.color
  )
end

function PANEL:rebuild()
  local text_wide, text_tall = util.text_size(self.html.inner_html, self.context.attributes.font_family)
  self:SetSize(text_wide, text_tall)
end

vgui.Register('_gvue_text', PANEL, 'gvue_basic_panel')

Gvue.alias('span', '_gvue_text')
Gvue.alias('text', '_gvue_text')
