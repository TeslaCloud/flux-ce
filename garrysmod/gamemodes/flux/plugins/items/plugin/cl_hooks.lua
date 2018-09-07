function flItems:PlayerUseItemMenu(itemTable, bIsEntity)
  if !itemTable then return end

  local itemMenu = vgui.Create("fl_menu")

  if !itemTable.name then
    local closeBtn = itemMenu:AddOption(itemTable.cancel_text or t('item.option.cancel'), function() print("Cancel") end)
    closeBtn:SetIcon("icon16/cross.png")
  else
    if itemTable.custom_buttons then
      for k, v in pairs(itemTable.custom_buttons) do
        if (v.onShow and v.onShow(itemTable) == true) or !v.onShow then
          local button = itemMenu:AddOption(k, function()
            itemTable:do_menu_action(v.callback)
          end)

          button:SetIcon(v.icon)
        end
      end
    end

    if itemTable.on_use then
      local useBtn = itemMenu:AddOption(itemTable:get_use_text(), function()
        itemTable:do_menu_action("on_use")
      end)

      useBtn:SetIcon(itemTable.use_icon or "icon16/wrench.png")
    end

    if bIsEntity then
      local takeBtn = itemMenu:AddOption(itemTable:get_take_text(), function()
        itemTable:do_menu_action("on_take")
      end)

      takeBtn:SetIcon(itemTable.take_icon or "icon16/wrench.png")
    else
      local dropBtn = itemMenu:AddOption(itemTable:get_drop_text(), function()
        itemTable:do_menu_action("on_drop")
      end)

      dropBtn:SetIcon(itemTable.take_icon or "icon16/wrench.png")
    end

    local closeBtn = itemMenu:AddOption(itemTable:get_cancel_text(), function() print("Cancel") end)
    closeBtn:SetIcon(itemTable.cancel_icon or "icon16/cross.png")
  end

  itemMenu:Open()

  if itemTable.entity then
    itemMenu:SetPos(ScrW() * 0.5, ScrH() * 0.5)
  else
    itemMenu:SetPos(gui.MouseX(), gui.MouseY())
  end
end

function flItems:PlayerDropItem(itemTable, panel, mouseX, mouseY)
  netstream.Start("PlayerDropItem", itemTable.instance_id)
end

function flItems:HUDPaint()
  local holdStart = fl.client:get_nv("HoldStart")

  if holdStart then
    local diff = math.Clamp(math.Round(CurTime() - holdStart, 3), 0.01, 0.5)
    local percentage = math.Clamp((diff / 0.5) * 100, 0, 100)

    fl.set_circle_percent(percentage)
  end
end

function flItems:Think()
  if !fl.client:get_nv("HoldStart") then return end

  local ent = fl.client:get_nv("HoldEnt")

  if IsValid(ent) and fl.client:get_nv("HoldStart") then
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
