--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

netstream.Hook("SharedTables", function(tSharedTable)
	rw.sharedTable = tSharedTable or {};
end);

netstream.Hook("PlayerInitialSpawn", function(nPlyIndex)
	plugin.Call("PlayerInitialSpawn", Entity(nPlyIndex));
end);

netstream.Hook("PlayerDisconnected", function(nPlyIndex)
	plugin.Call("PlayerDisconnected", Entity(nPlyIndex));
end);

netstream.Hook("PlayerModelChanged", function(nPlyIndex, sNewModel, sOldModel)
	util.WaitForEntity(nPlyIndex, function(player)
		plugin.Call("PlayerModelChanged", player, sNewModel, sOldModel);
	end);
end);

netstream.Hook("PostCharacterLoaded", function(nCharID)
	if (rw.client.IntroPanel) then
		rw.client.IntroPanel:SetVisible(false);
		rw.client.IntroPanel:Remove();
	end;
end);

netstream.Hook("reNotification", function(sMessage)
	sMessage = rw.lang:TranslateText(sMessage);

	chat.AddText(Color(255, 255, 255), sMessage);
end);

netstream.Hook("PlayerUseItemEntity", function(entity)
	local itemTable = entity.item;

	if (!itemTable) then return; end;

	local itemMenu = DermaMenu();

	if (itemTable.customButtons) then
		for k, v in pairs(itemTable.customButtons) do
			local button = itemMenu:AddOption(k, function() 
				itemTable:DoMenuAction(v.callback);
			end);
			button:SetIcon(v.icon);
		end;
	end;

	if (itemTable.OnUse) then
		local useBtn = itemMenu:AddOption(itemTable.useText or "Use", function() 
			itemTable:DoMenuAction("OnUse");
		end);
		useBtn:SetIcon(itemTable.useIcon or "icon16/wrench.png");
	end;

	if (itemTable.OnTake) then
		local takeBtn = itemMenu:AddOption(itemTable.takeText or "Take", function() 
			itemTable:DoMenuAction("OnTake");
		end);
		takeBtn:SetIcon(itemTable.takeIcon or "icon16/wrench.png");
	end;

	local closeBtn = itemMenu:AddOption(itemTable.cancelText or "Cancel", function() end);
	closeBtn:SetIcon(itemTable.cancelIcon or "icon16/cross.png");

	itemMenu:Open()

	itemMenu:SetPos(ScrW() / 2, ScrH() / 2);
end);