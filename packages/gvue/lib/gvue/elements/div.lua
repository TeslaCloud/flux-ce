local PANEL = Gvue.new_panel()
PANEL.element_name = 'div'

vgui.Register('_gvue_div', PANEL, 'gvue_basic_panel')

Gvue.alias('div', '_gvue_div')
