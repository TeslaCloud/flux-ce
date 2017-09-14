--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

util.Include("sv_hooks.lua")
util.Include("cl_hooks.lua")

do
	flPrefixes:AddPrefix({"//", "/ooc"}, function(player, text, bTeamChat)
		local message = {
			Color("red"),
			"[OOC]",
			hook.Run("ChatboxGetPlayerIcon", player, text, bTeamChat) or {},
			hook.Run("ChatboxGetPlayerColor", player, text, bTeamChat) or _team.GetColor(player:Team()),
			player,
			hook.Run("ChatboxGetMessageColor", player, text, bTeamChat) or Color(255, 255, 255),
			": ",
			text,
			{sender = player}
		}

		chatbox.AddText(nil, unpack(message))
	end)

	flPrefixes:AddPrefix({".//", "[[", "/looc"}, function(player, text, bTeamChat)
		local message = {
			Color("crimson"),
			"[LOOC]",
			hook.Run("ChatboxGetPlayerIcon", player, text, bTeamChat) or {},
			hook.Run("ChatboxGetPlayerColor", player, text, bTeamChat) or _team.GetColor(player:Team()),
			player,
			Color(config.Get("ic_color")),
			": ",
			text,
			{sender = player},
			position = player:GetPos(),
			radius = config.Get("talk_radius")
		}

		chatbox.AddText(nil, unpack(message))
	end)
end