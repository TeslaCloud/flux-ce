--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
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