function Items:HUDPaint()
  if !IsValid(PLAYER) then return end

  local hold_start = PLAYER:get_nv('hold_start')

  if hold_start then
    local diff = math.Clamp(math.Round(CurTime() - hold_start, 3), 0.01, 0.5)
    local percentage = math.Clamp((diff / 0.5) * 100, 0, 100)

    Flux.set_circle_percent(percentage)
  end
end

function Items:PreDrawHalos()
  if !IsValid(PLAYER) then return end

  local ent = PLAYER:get_nv('hold_entity')

  if IsValid(ent) then
    halo.Add({ ent }, color_white)
  end
end

function Items:Think()
  if !IsValid(PLAYER) or !PLAYER:get_nv('hold_start') then return end

  local ent = PLAYER:get_nv('hold_entity')

  if IsValid(ent) and PLAYER:get_nv('hold_start') then
    local scr_pos = ent:GetPos():ToScreen()
    local x, y = scr_pos.x, scr_pos.y
    local w, h = ScrW() * 0.5, ScrH() * 0.5

    if !scr_pos.visible or math.abs(w - x) > Font.scale(350) or math.abs(h - y) > Font.scale(350) then
      Cable.send('fl_items_abort_hold_start', true)
    end
  end
end

function Items:PlayerUseItemMenu(instance_id, is_entity)
  local item_table = Item.find_instance_by_id(instance_id)

  if !item_table then return end

  if hook.run('CanItemMenuOpen', item_table) == false then return end

  local item_menu = vgui.Create('fl_menu')

  if item_table.name then
    if item_table.custom_buttons then
      for k, v in pairs(item_table.custom_buttons) do
        if (v.on_show and v.on_show(item_table) == true) or !v.on_show then
          local button = item_menu:add_option(k, function()
            item_table:do_menu_action(v.callback)
          end)

          button:SetIcon(v.icon)
        end
      end
    end

    if item_table.on_use then
      if !item_table.is_action_visible or item_table:is_action_visible('use') != false then
        local use_button = item_menu:add_option(item_table:get_use_text(), function()
          item_table:do_menu_action('on_use')
        end)

        use_button:SetIcon(item_table.use_icon or 'icon16/wrench.png')
      end
    end

    if is_entity then
      if !item_table.is_action_visible or item_table:is_action_visible('take') != false then
        local take_button = item_menu:add_option(item_table:get_take_text(), function()
          item_table:do_menu_action('on_take')
        end)

        take_button:SetIcon(item_table.take_icon or 'icon16/wrench.png')
      end
    else
      if !item_table.is_action_visible or item_table:is_action_visible('drop') != false then
        local drop_button = item_menu:add_option(item_table:get_drop_text(), function()
          item_table:do_menu_action('on_drop')
        end)

        drop_button:SetIcon(item_table.take_icon or 'icon16/wrench.png')
      end
    end
  end

  item_menu:open()

  if is_entity then
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

  item_menu:SetKeyboardInputEnabled(true)
end

function Items:PlayerDropItem(item_table, panel, mouse_x, mouse_y)
  Cable.send('fl_player_drop_item', item_table.instance_id)
end

function Items:OnItemDataReceived()
  for k, v in ipairs(ents.GetAll()) do
    if IsValid(v) and v:GetClass() == 'fl_item' then
      Cable.send('fl_items_data_request', v:EntIndex())
    end
  end
end

Cable.receive('fl_player_use_item_entity', function(entity)
  hook.run('PlayerUseItemMenu', entity.item.instance_id, true)
end)
