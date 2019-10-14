local PANEL = Gvue.new_panel()
PANEL.element_name = 'div'

function PANEL:rebuild()
  local w, h = self:ChildrenSize()
  self:SetSize(w, h)
end

vgui.Register('_gvue_div', PANEL, 'gvue_basic_panel')

Gvue.alias('div', '_gvue_div')
