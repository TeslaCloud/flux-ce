function Currencies:OnInventoryRebuild(panel)
  if panel:get_inventory_type() == 'pockets' then
    local parent = panel:GetParent()

    if !IsValid(parent.money) then
      parent.money = vgui.create('fl_currencies', parent)
    end

    local text = t(parent.money.title)
    local font = Theme.get_font('main_menu_normal_large')
    local text_w, text_h = util.text_size(text, font)

    parent.money:rebuild()
    parent.money:SizeToContents()
    panel:SetWide(math.min(panel:GetWide(), parent.main_inventory:GetWide() - parent.money:GetWide() - math.scale(16)))
    parent.money:SetPos(panel.x + panel:GetWide() + math.scale(8), panel.y + math.max(panel:GetTall() - parent.money:GetTall(), text_h))
  end
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
