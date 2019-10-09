local PANEL = Gvue.new_panel()
PANEL.element_name = 'div'

vgui.Register('_gvue_div', PANEL, 'gvue_basic_panel')

Gvue.alias('div', '_gvue_div')

concommand.Add('gvue_test', function()
  if IsValid(__GVUE_PANE__) then
    __GVUE_PANE__:SetVisible(false)
    __GVUE_PANE__:Remove()
  end

  __GVUE_PANE__ = Gvue.spawn_panel('div')
  __GVUE_PANE__:SetSize(512, 256)
  __GVUE_PANE__:SetPos(64, 64)
  __GVUE_PANE__.draw_debug_overlay = true

  local text_pane = Gvue.spawn_panel('span', __GVUE_PANE__)
  text_pane.html.inner_html = 'Hello World, I am <span>!'
  text_pane.context.attributes.font_family = 'DermaLarge'
  text_pane:SetPos(8, 24)
  text_pane.draw_debug_overlay = true
  text_pane:rebuild()
end)

concommand.Add('gvue_close', function()
  __GVUE_PANE__:SetVisible(false)
  __GVUE_PANE__:Remove()
end)
