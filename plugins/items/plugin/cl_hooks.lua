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

    if !scr_pos.visible or math.abs(w - x) > math.scale(350) or math.abs(h - y) > math.scale(350) then
      Cable.send('fl_items_abort_hold_start', true)
    end
  end
end

function Items:PlayerUseItemMenu(instance_id, is_entity)
  local item_obj = Item.find_instance_by_id(instance_id)

  if !item_obj then return end

  if hook.run('CanItemMenuOpen', item_obj) == false then return end

  local item_menu = vgui.Create('fl_menu')

  if item_obj.name then
    if item_obj.custom_buttons then
      for k, v in pairs(item_obj.custom_buttons) do
        if !v.on_show or v.on_show(item_obj) != false  then
          local button = item_menu:add_option(t(v.get_name and v.get_name(item_obj) or v.name or k), function()
            if v.on_click then
              v.on_click(item_obj)
            end

            item_obj:do_menu_action(v.callback)
          end)

          button:SetIcon(v.get_icon and v.get_icon(item_obj) or v.icon)
        end
      end
    end

    if item_obj.on_use then
      if !item_obj.is_action_visible or item_obj:is_action_visible('use') != false then
        local use_button = item_menu:add_option(t(item_obj:get_use_text()), function()
          item_obj:do_menu_action('on_use')
        end)

        use_button:SetIcon(item_obj.use_icon or 'icon16/accept.png')
      end
    end

    if is_entity then
      if !item_obj.is_action_visible or item_obj:is_action_visible('take') != false then
        local take_button = item_menu:add_option(t(item_obj:get_take_text()), function()
          item_obj:do_menu_action('on_take')
        end)

        take_button:SetIcon(item_obj.take_icon or 'icon16/add.png')
      end
    else
      if !item_obj.is_action_visible or item_obj:is_action_visible('drop') != false then
        local drop_button = item_menu:add_option(t(item_obj:get_drop_text()), function()
          item_obj:do_menu_action('on_drop')
        end)

        drop_button:SetIcon(item_obj.take_icon or 'icon16/arrow_down.png')
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
end

function Items:OnItemDataReceived()
  for k, v in ipairs(ents.GetAll()) do
    if IsValid(v) and v:GetClass() == 'fl_item' then
      Cable.send('fl_items_data_request', v:EntIndex())
    end
  end
end

Cable.receive('fl_player_use_item_entity', function(entity)
  if IsValid(entity) and entity.item then
    hook.run('PlayerUseItemMenu', entity.item.instance_id, true)
  end
end)
