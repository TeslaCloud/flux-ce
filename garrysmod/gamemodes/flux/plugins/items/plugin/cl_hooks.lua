function flItems:PlayerUseItemMenu(item_table, bIsEntity)
  if !item_table then return end

  local itemMenu = vgui.Create("fl_menu")

  if !item_table.name then
    local closeBtn = itemMenu:AddOption(item_table.cancel_text or t('item.option.cancel'), function() end)
    closeBtn:SetIcon("icon16/cross.png")
  else
    if item_table.custom_buttons then
      for k, v in pairs(item_table.custom_buttons) do
        if (v.onShow and v.onShow(item_table) == true) or !v.onShow then
          local button = itemMenu:AddOption(k, function()
            item_table:do_menu_action(v.callback)
          end)

          button:SetIcon(v.icon)
        end
      end
    end

    if item_table.on_use then
      local useBtn = itemMenu:AddOption(item_table:get_use_text(), function()
        item_table:do_menu_action("on_use")
      end)

      useBtn:SetIcon(item_table.use_icon or "icon16/wrench.png")
    end

    if bIsEntity then
      local takeBtn = itemMenu:AddOption(item_table:get_take_text(), function()
        item_table:do_menu_action("on_take")
      end)

      takeBtn:SetIcon(item_table.take_icon or "icon16/wrench.png")
    else
      local dropBtn = itemMenu:AddOption(item_table:get_drop_text(), function()
        item_table:do_menu_action("on_drop")
      end)

      dropBtn:SetIcon(item_table.take_icon or "icon16/wrench.png")
    end

    local closeBtn = itemMenu:AddOption(item_table:get_cancel_text(), function() end)
    closeBtn:SetIcon(item_table.cancel_icon or "icon16/cross.png")
  end

  itemMenu:Open()

  if item_table.entity then
    itemMenu:SetPos(ScrW() * 0.5, ScrH() * 0.5)
  else
    itemMenu:SetPos(gui.MouseX(), gui.MouseY())
  end
end

function flItems:PlayerDropItem(item_table, panel, mouseX, mouseY)
  netstream.Start("PlayerDropItem", item_table.instance_id)
end

function flItems:HUDPaint()
  local holdStart = fl.client:get_nv('hold_start')

  if holdStart then
    local diff = math.Clamp(math.Round(CurTime() - holdStart, 3), 0.01, 0.5)
    local percentage = math.Clamp((diff / 0.5) * 100, 0, 100)

    fl.set_circle_percent(percentage)
  end
end

function flItems:Think()
  if !fl.client:get_nv('hold_start') then return end

  local ent = fl.client:get_nv('hold_entity')

  if IsValid(ent) and fl.client:get_nv('hold_start') then
    local scrPos = ent:GetPos():ToScreen()
    local x, y = scrPos.x, scrPos.y
    local w, h = ScrW() * 0.5, ScrH() * 0.5

    if !scrPos.visible or math.abs(w - x) > font.Scale(350) or math.abs(h - y) > font.Scale(350) then
      netstream.Start("Flux::Items::AbortHoldStart", true)
    end
  end
end

function flItems:OnItemDataReceived()
  for k, v in ipairs(ents.GetAll()) do
    if IsValid(v) and v:GetClass() == "fl_item" then
      netstream.Start("RequestItemData", v:EntIndex())
    end
  end
end

netstream.Hook("PlayerUseItemEntity", function(entity)
  hook.run("PlayerUseItemMenu", entity.item, true)
end)
