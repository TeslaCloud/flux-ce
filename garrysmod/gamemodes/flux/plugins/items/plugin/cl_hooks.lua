function flItems:PlayerUseItemMenu(item_table, is_entity)
  if !item_table then return end

  local item_menu = vgui.Create('fl_menu')

  if !item_table.name then
    local close_button = item_menu:AddOption(item_table.cancel_text or t'item.option.cancel', function() end)
    close_button:SetIcon('icon16/cross.png')
  else
    if item_table.custom_buttons then
      for k, v in pairs(item_table.custom_buttons) do
        if (v.on_show and v.on_show(item_table) == true) or !v.on_show then
          local button = item_menu:AddOption(k, function()
            item_table:do_menu_action(v.callback)
          end)

          button:SetIcon(v.icon)
        end
      end
    end

    if item_table.on_use then
      local use_button = item_menu:AddOption(item_table:get_use_text(), function()
        item_table:do_menu_action('on_use')
      end)

      use_button:SetIcon(item_table.use_icon or 'icon16/wrench.png')
    end

    if is_entity then
      local take_button = item_menu:AddOption(item_table:get_take_text(), function()
        item_table:do_menu_action('on_take')
      end)

      take_button:SetIcon(item_table.take_icon or 'icon16/wrench.png')
    else
      local drop_button = item_menu:AddOption(item_table:get_drop_text(), function()
        item_table:do_menu_action('on_drop')
      end)

      drop_button:SetIcon(item_table.take_icon or 'icon16/wrench.png')
    end

    local close_button = item_menu:AddOption(item_table:get_cancel_text(), function() end)
    close_button:SetIcon(item_table.cancel_icon or 'icon16/cross.png')
  end

  item_menu:Open()

  if item_table.entity then
    item_menu:SetPos(ScrW() * 0.5, ScrH() * 0.5)
  else
    local x, y = gui.MouseX(), gui.MouseY()

    if x + item_menu:GetWide() > ScrW() then
      x = x - item_menu:GetWide()
    end

    if y + item_menu:GetTall() > ScrH() then
      y = y - item_menu:GetTall()
    end

    item_menu:SetPos(x, y)
  end
end

function flItems:PlayerDropItem(item_table, panel, mousex, mousey)
  cable.send('PlayerDropItem', item_table.instance_id)
end

function flItems:HUDPaint()
  local hold_start = fl.client:get_nv('hold_start')

  if hold_start then
    local diff = math.Clamp(math.Round(CurTime() - hold_start, 3), 0.01, 0.5)
    local percentage = math.Clamp((diff / 0.5) * 100, 0, 100)

    fl.set_circle_percent(percentage)
  end
end

function flItems:PreDrawHalos()
  local ent = fl.client:get_nv('hold_entity')

  if IsValid(ent) then
    halo.Add({ ent }, color_white)
  end
end

function flItems:Think()
  if !fl.client:get_nv('hold_start') then return end

  local ent = fl.client:get_nv('hold_entity')

  if IsValid(ent) and fl.client:get_nv('hold_start') then
    local scr_pos = ent:GetPos():ToScreen()
    local x, y = scr_pos.x, scr_pos.y
    local w, h = ScrW() * 0.5, ScrH() * 0.5

    if !scr_pos.visible or math.abs(w - x) > font.scale(350) or math.abs(h - y) > font.scale(350) then
      cable.send('Flux::Items::Aborthold_start', true)
    end
  end
end

function flItems:OnItemDataReceived()
  for k, v in ipairs(ents.GetAll()) do
    if IsValid(v) and v:GetClass() == 'fl_item' then
      cable.send('RequestItemData', v:EntIndex())
    end
  end
end

cable.receive('PlayerUseItemEntity', function(entity)
  hook.run('PlayerUseItemMenu', entity.item, true)
end)
