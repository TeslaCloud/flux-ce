--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

netstream.Hook("SharedTables", function(tSharedTable)
	rw.sharedTable = tSharedTable or {}
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

netstream.Hook("PostCharacterLoaded", function(nCharID)
	if (IsValid(rw.IntroPanel)) then
		rw.IntroPanel:SafeRemove()
	end
end)

netstream.Hook("rwNotification", function(sMessage)
	sMessage = rw.lang:TranslateText(sMessage)

	rw.notification:Add(sMessage, 8, Color(175, 175, 235))

	chat.AddText(Color(255, 255, 255), sMessage)
end)

netstream.Hook("PlayerUseItemEntity", function(entity)
	hook.Run("PlayerUseItemMenu", entity.item, true)
end)

netstream.Hook("PlayerTakeDamage", function()
	rw.client.lastDamage = CurTime()
end)

netstream.Hook("RefreshInventory", function()
	if (rw.tabMenu and rw.tabMenu.activePanel and rw.tabMenu.activePanel.Rebuild) then
		rw.tabMenu.activePanel:Rebuild()
	end
end)

netstream.Hook("PlayerCreatedCharacter", function(success, status)
	if (IsValid(rw.IntroPanel) and IsValid(rw.IntroPanel.menu)) then
		if (success) then
			rw.IntroPanel:RecreateSidebar(true)

			if (rw.IntroPanel.menu.Close) then
				rw.IntroPanel.menu:Close()
			else
				rw.IntroPanel.menu:SafeRemove()
			end
		else
			local text = "We were unable to create a character! (unknown error)"

			if (status == CHAR_ERR_NAME) then
				text = "Your character's name must be between "..config.Get("character_min_name_len").." and "..config.Get("character_max_name_len").." characters long!"
			elseif (status == CHAR_ERR_DESC) then
				text = "Your character's description must be between "..config.Get("character_min_desc_len").." and "..config.Get("character_max_desc_len").." characters long!"
			elseif (status == CHAR_ERR_GENDER) then
				text = "You must pick a gender for your character before continuing!"
			end

			local panel = vgui.Create("rwNotification", rw.IntroPanel)
			panel:SetText(text)
			panel:SetLifetime(6)
			panel:SetTextColor(Color("red"))
			panel:SetBackgroundColor(Color(50, 50, 50, 220))

			local w, h = panel:GetSize()
			panel:SetPos(ScrW() / 2 - w / 2, ScrH() - 128)

			function panel:PostThink() self:MoveToFront() end
		end
	end
end)

netstream.Hook("PlayerEnteredArea", function(areaIdx, idx, pos, curTime)
	local area = areas.GetAll()[areaIdx]

	Try("Areas", areas.GetCallback(area.type), rw.client, area, area.polys[idx], true, pos, curTime)
end)

netstream.Hook("PlayerLeftArea", function(areaIdx, idx, pos, curTime)
	local area = areas.GetAll()[areaIdx]

	Try("Areas", areas.GetCallback(area.type), rw.client, area, area.polys[idx], false, pos, curTime)
end)