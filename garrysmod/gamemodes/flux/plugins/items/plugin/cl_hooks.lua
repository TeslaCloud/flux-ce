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
				if ((v.onShow and v.onShow(itemTable) == true) or !v.onShow) then
					local button = itemMenu:AddOption(k, function()
						itemTable:DoMenuAction(v.callback)
					end)

					button:SetIcon(v.icon)
				end
			end
		end

		if (itemTable.OnUse) then
			local useBtn = itemMenu:AddOption(itemTable:GetUseText(), function()
				itemTable:DoMenuAction("OnUse")
			end)

			useBtn:SetIcon(itemTable.UseIcon or "icon16/wrench.png")
		end

		if (bIsEntity) then
			local takeBtn = itemMenu:AddOption(itemTable:GetTakeText(), function()
				itemTable:DoMenuAction("OnTake")
			end)

			takeBtn:SetIcon(itemTable.TakeIcon or "icon16/wrench.png")
		else
			local dropBtn = itemMenu:AddOption(itemTable:GetDropText(), function()
				itemTable:DoMenuAction("OnDrop")
			end)

			dropBtn:SetIcon(itemTable.TakeIcon or "icon16/wrench.png")
		end

		local closeBtn = itemMenu:AddOption(itemTable:GetCancelText(), function() end)
		closeBtn:SetIcon(itemTable.CancelIcon or "icon16/cross.png")
	end

	itemMenu:Open()

	if (itemTable.entity) then
		itemMenu:SetPos(ScrW() * 0.5, ScrH() * 0.5)
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

		fl.SetCirclePercentage(percentage)
	end
end

function flItems:Think()
	if (!fl.client:GetNetVar("HoldStart")) then return end

	local ent = fl.client:GetNetVar("HoldEnt")

	if (IsValid(ent) and fl.client:GetNetVar("HoldStart")) then
		local scrPos = ent:GetPos():ToScreen()
		local x, y = scrPos.x, scrPos.y
		local w, h = ScrW() * 0.5, ScrH() * 0.5

		if (!scrPos.visible or math.abs(w - x) > font.Scale(350) or math.abs(h - y) > font.Scale(350)) then
			netstream.Start("Flux::Items::AbortHoldStart", true)
		end
	end
end

netstream.Hook("PlayerUseItemEntity", function(entity)
	hook.Run("PlayerUseItemMenu", entity.item, true)
end)