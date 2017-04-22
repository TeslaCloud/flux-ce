--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

netstream.Hook("SharedTables", function(tSharedTable)
	fl.sharedTable = tSharedTable or {}
	fl.sharedTableReceived = true
end)

netstream.Hook("Hook_RunCL", function(hookName, ...)
	hook.Run(hookName, ...)
end)

netstream.Hook("PlayerInitialSpawn", function(nPlyIndex)
	hook.Run("PlayerInitialSpawn", Entity(nPlyIndex))
end)

netstream.Hook("PlayerDisconnected", function(nPlyIndex)
	hook.Run("PlayerDisconnected", Entity(nPlyIndex))
end)

netstream.Hook("PlayerModelChanged", function(nPlyIndex, sNewModel, sOldModel)
	util.WaitForEntity(nPlyIndex, function(player)
		hook.Run("PlayerModelChanged", player, sNewModel, sOldModel)
	end)
end)

netstream.Hook("flNotification", function(sMessage)
	sMessage = fl.lang:TranslateText(sMessage)

	fl.notification:Add(sMessage, 8, Color(175, 175, 235))

	chat.AddText(Color(255, 255, 255), sMessage)
end)

netstream.Hook("PlayerUseItemEntity", function(entity)
	hook.Run("PlayerUseItemMenu", entity.item, true)
end)

netstream.Hook("PlayerTakeDamage", function()
	fl.client.lastDamage = CurTime()
end)

netstream.Hook("RefreshInventory", function()
	if (fl.tabMenu and fl.tabMenu.activePanel and fl.tabMenu.activePanel.Rebuild) then
		fl.tabMenu.activePanel:Rebuild()
	end
end)

netstream.Hook("PlayerEnteredArea", function(areaIdx, idx, pos, curTime)
	local area = areas.GetAll()[areaIdx]

	Try("Areas", areas.GetCallback(area.type), fl.client, area, area.polys[idx], true, pos, curTime)
end)

netstream.Hook("PlayerLeftArea", function(areaIdx, idx, pos, curTime)
	local area = areas.GetAll()[areaIdx]

	Try("Areas", areas.GetCallback(area.type), fl.client, area, area.polys[idx], false, pos, curTime)
end)