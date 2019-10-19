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

function Currencies:CreatePlayerInteractions(menu, target)
  local money_menu, money_menu_option = menu:AddSubMenu(t'ui.currency.title')
  money_menu_option:SetIcon('icon16/money.png')

  for k, v in pairs(Currencies.all()) do
    local amount = PLAYER:get_money(k) or 0

    if !v.hidden or v.hidden and amount > 0 then
      money_menu:AddOption(t'ui.currency.menu.give'..' '..t(v.name), function()
        Derma_StringRequest(t'ui.currency.give.title', t('ui.currency.give.message', { currency = t(v.name) }), '', function(text)
          local value = tonumber(text)

          if value and value > 0 then
            Cable.send('fl_currency_give', value, k, target)
          else
            PLAYER:notify('error.invalid_amount')
          end
        end)
      end)
    end
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
