--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flItems:PlayerUseItemMenu(itemTable, bIsEntity)
	if (!itemTable) then return end

	local itemMenu = DermaMenu()

	if (!itemTable.Name) then
		local closeBtn = itemMenu:AddOption(itemTable.CancelText or "#Item_Option_Cancel", function() end)
		closeBtn:SetIcon("icon16/cross.png")
	else
		if (itemTable.customButtons) then
			for k, v in pairs(itemTable.customButtons) do
				local button = itemMenu:AddOption(k, function()
					itemTable:DoMenuAction(v.callback)
				end)

				button:SetIcon(v.icon)
			end
		end

		if (itemTable.OnUse) then
			local useBtn = itemMenu:AddOption(itemTable.UseText or "#Item_Option_Use", function()
				itemTable:DoMenuAction("OnUse")
			end)

			useBtn:SetIcon(itemTable.UseIcon or "icon16/wrench.png")
		end

		if (bIsEntity) then
			local takeBtn = itemMenu:AddOption(itemTable.TakeText or "#Item_Option_Take", function()
				itemTable:DoMenuAction("OnTake")
			end)

			takeBtn:SetIcon(itemTable.TakeIcon or "icon16/wrench.png")
		else
			local dropBtn = itemMenu:AddOption(itemTable.TakeText or "#Item_Option_Drop", function()
				itemTable:DoMenuAction("OnDrop")
			end)

			dropBtn:SetIcon(itemTable.TakeIcon or "icon16/wrench.png")
		end

		local closeBtn = itemMenu:AddOption(itemTable.CancelText or "#Item_Option_Cancel", function() end)
		closeBtn:SetIcon(itemTable.CancelIcon or "icon16/cross.png")
	end

	itemMenu:Open()

	if (itemTable.entity) then
		itemMenu:SetPos(ScrW() / 2, ScrH() / 2)
	else
		itemMenu:SetPos(gui.MouseX(), gui.MouseY())
	end
end

function flItems:PlayerDropItem(itemTable, panel, mouseX, mouseY)
	netstream.Start("PlayerDropItem", itemTable.instanceID)
end

function flItems:HUDPaint()
	local holdStart = fl.client:GetNetVar("HoldStart")

	if (holdStart) then
		local diff = math.Clamp(math.Round(CurTime() - holdStart, 3), 0.01, 0.5)
		local percentage = math.Clamp((diff / 0.5) * 100, 0, 100)

		surface.SetDrawColor(theme.GetColor("Text"))
		surface.DrawPartialOutlinedCircle(percentage, ScrW() / 2, ScrH() / 2, 32, 3, 64)
	end
end

netstream.Hook("PlayerUseItemEntity", function(entity)
	hook.Run("PlayerUseItemMenu", entity.item, true)
end)