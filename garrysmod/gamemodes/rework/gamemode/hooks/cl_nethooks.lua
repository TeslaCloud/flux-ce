--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

netstream.Hook("SharedTables", function(tSharedTable)
	rw.sharedTable = tSharedTable or {};
end);

netstream.Hook("PlayerInitialSpawn", function(nPlyIndex)
	hook.Run("PlayerInitialSpawn", Entity(nPlyIndex));
end);

netstream.Hook("PlayerDisconnected", function(nPlyIndex)
	hook.Run("PlayerDisconnected", Entity(nPlyIndex));
end);

netstream.Hook("PlayerModelChanged", function(nPlyIndex, sNewModel, sOldModel)
	util.WaitForEntity(nPlyIndex, function(player)
		hook.Run("PlayerModelChanged", player, sNewModel, sOldModel);
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
	hook.Run("PlayerUseItemMenu", entity.item, true);
end);

netstream.Hook("PlayerTakeDamage", function()
	rw.client.lastDamage = CurTime();
end);

netstream.Hook("RefreshInventory", function()
	if (rw.tabMenu and rw.tabMenu.activePanel and rw.tabMenu.activePanel.Rebuild) then
		rw.tabMenu.activePanel:Rebuild();
	end;
end);