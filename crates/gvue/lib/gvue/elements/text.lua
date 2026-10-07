local PANEL = Gvue.new_panel()
PANEL.element_name = 'text'

--- Draws the element's text using its font_family and color attributes.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:draw(w, h)
  draw.SimpleText(
    self.html.inner_html,
    self.context.attributes.font_family,
    0,
    0,
    self.context.attributes.color
  )
end

--- Resizes the element to fit its text.
function PANEL:rebuild()
  local text_wide, text_tall = util.text_size(self.html.inner_html, self.context.attributes.font_family)
  self:SetSize(text_wide, text_tall)
end

vgui.Register('_gvue_text', PANEL, 'gvue_basic_panel')

Gvue.alias('text', '_gvue_text')
Gvue.alias('text_node', '_gvue_text')
