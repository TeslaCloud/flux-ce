function Currencies:OnInventoryRebuild(panel, first)
  if first then
    panel.money = vgui.create('fl_currencies', panel)
  end

  local text = t(panel.money.title)
  local font = Theme.get_font('text_normal')
  local text_w, text_h = util.text_size(text, font)

  panel.money:set_currencies(PLAYER:get_nv('fl_currencies'))
  panel.money:rebuild()
  panel.money:SizeToContents()
  panel.money:SetPos(panel.pockets.x + panel.pockets:GetWide() + 8, panel.pockets.y + math.max(panel.pockets:GetTall() - panel.money:GetTall(), text_h))
end
