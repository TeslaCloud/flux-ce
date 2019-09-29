function Currencies:OnInventoryRebuild(panel)
  panel.money = vgui.create('fl_currencies', panel)

  local text = t(panel.money.title)
  local font = Theme.get_font('main_menu_normal_large')
  local text_w, text_h = util.text_size(text, font)

  panel.money:rebuild()
  panel.money:SizeToContents()
  panel.money:SetPos(panel.pockets.x + panel.pockets:GetWide() + math.scale(8), panel.pockets.y + math.max(panel.pockets:GetTall() - panel.money:GetTall(), text_h))
end

Cable.receive('fl_rebuild_currency_panel', function()
  if IsValid(Flux.tab_menu) and Flux.tab_menu:IsVisible() then
    local active_panel = Flux.tab_menu.active_panel

    if IsValid(active_panel) and active_panel.id == 'inventory' then
      local money_panel = active_panel.money

      if IsValid(money_panel) then
        money_panel:rebuild()
      end
    end
  end
end)
