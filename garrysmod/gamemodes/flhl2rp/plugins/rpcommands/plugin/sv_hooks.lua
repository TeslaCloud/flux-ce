--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

config.Set("talk_radius", 400)
config.Set("ic_color", "khaki")

function PLUGIN:ChatboxAdjustPlayerSay(player, text, messageData)
	table.Empty(messageData)

	table.Merge(messageData, {
		Color(config.Get("ic_color")),
		player:Name(),
		L("Chat_Say"),
		hook.Run("ChatboxAdjustICText", text:Spelling())
	})
end

function PLUGIN:PlayerCanHear(player, messageData)
	if (messageData.hearWhenLook) then
		local lookPos = player:GetEyeTraceNoCursor().HitPos

		return messageData.sender:GetPos():Distance(lookPos) <= messageData.radius
	end
end

function PLUGIN:ChatboxAdjustICText(text)
	return "\""..text.."\""
end

function PLUGIN:PlayerCanUseOOC(player)
	if (player:GetPlayerData("MuteOOC", 0) > CurTime()) then
		return false
	end
end
