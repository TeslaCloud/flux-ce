--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flChatbox:ChatboxGetPlayerIcon(player, text, bTeamChat)
	return {image = "materials/icon16/shield.png", width = 16, height = 16, isData = true}
end

function flChatbox:ChatboxGetPlayerColor(player, text, bTeamChat)
	return _team.GetColor(player:Team()) or Color(255, 255, 255)
end

function flChatbox:ChatboxGetMessageColor(player, text, bTeamChat)
	return Color(255, 255, 255)
end