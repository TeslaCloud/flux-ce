function Currencies:OnInventoryRebuild(panel)
  if panel:get_inventory_type() == 'pockets' then
    local parent = panel:GetParent()

    if !IsValid(panel.money) then
      local owner = Inventories.find(panel:get_inventory_id()).owner

      panel.money = self:create_panel(owner, parent)
    else
      panel.money:rebuild()
    end

    local text = t(panel.money.title)
    local font = Theme.get_font('main_menu_normal_large')
    local text_w, text_h = util.text_size(text, font)

    if IsValid(panel.main_inventory) then
      panel:SetWide(math.min(panel:GetWide(), panel.main_inventory:GetWide() - panel.money:GetWide() - math.scale(16)))
    end

    panel.money:SetPos(panel.x + panel:GetWide() + math.scale(8), panel.y + math.max(panel:GetTall() - panel.money:GetTall(), text_h))
  end
end

function Currencies:OnConatinerOpened(panel, inventory_id)
  local inventory = Inventories.find(inventory_id)
  local inv_panel = panel.inventory

  if inventory.instance_id then return end

  if !IsValid(panel.container_money) then
    panel.container_money = self:create_panel(inventory.owner, panel)
  else
    panel.container_money:rebuild()
  end

  local text = t(panel.container_money.title)
  local font = Theme.get_font('main_menu_normal_large')
  local text_w, text_h = util.text_size(text, font)

  panel.container_money:SetPos(inv_panel.x, inv_panel.y + inv_panel:GetTall() + text_h + math.scale(8))
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

function Currencies:create_panel(entity, parent)
  local money_panel = vgui.create('fl_currencies', parent)
  money_panel:set_entity(entity)
  money_panel:rebuild()
  money_panel.OnRemove = function(pnl)
    if IsValid(pnl) then
      table.remove_by_value(Flux.money_panels, pnl)
    end
  end

  Flux.money_panels = Flux.money_panels or {}
  table.insert(Flux.money_panels, money_panel)

  return money_panel
end

Cable.receive('fl_rebuild_currency_panel', function()
  for k, v in pairs(Flux.money_panels) do
    if IsValid(v) then
      v:rebuild()
    end
  end
end)
