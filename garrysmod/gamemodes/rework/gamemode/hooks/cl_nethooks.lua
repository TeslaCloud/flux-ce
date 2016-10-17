--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

netstream.Hook("SharedTables", function(sharedTable)
	rw.sharedTable = sharedTable or {};
end);

netstream.Hook("PlayerInitialSpawn", function(plyIndex)
	plugin.Call("PlayerInitialSpawn", Entity(plyIndex));
end);

netstream.Hook("PlayerDisconnected", function(plyIndex)
	plugin.Call("PlayerDisconnected", Entity(plyIndex));
end);

netstream.Hook("PostCharacterLoaded", function(charID)
	if (rw.client.IntroPanel) then
		rw.client.IntroPanel:SetVisible(false);
		rw.client.IntroPanel:Remove();
	end;
end);

netstream.Hook("reNotification", function(message)
	message = rw.lang:TranslateText(message);

	chat.AddText(Color(255, 255, 255), message);
end);