--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

util.Include("sv_hooks.lua")
util.Include("cl_hooks.lua")

do
	flPrefixes:AddPrefix({"//", "/ooc"}, function(player, text, bTeamChat)
		if (hook.Run("PlayerCanUseOOC", player) == false) then 
			player:Notify(L("MutedNotify", fl.lang:NiceTimeFull(player:GetNetVar("language"), math.Round(player:GetPlayerData("MuteOOC") - CurTime()))))

			return
		end

		chatbox.AddText(nil,
			Color("red"), "[OOC]",
			hook.Run("ChatboxGetPlayerIcon", player, text, bTeamChat) or {},
			hook.Run("ChatboxGetPlayerColor", player, text, bTeamChat) or _team.GetColor(player:Team()),
			player,
			hook.Run("ChatboxGetMessageColor", player, text, bTeamChat) or Color(255, 255, 255),
			": ",
			text,
			{sender = player}
		)
	end)

	flPrefixes:AddPrefix({".//", "[[", "/looc "}, function(player, text, bTeamChat)
		if (hook.Run("PlayerCanUseOOC", player) == false) then
			player:Notify(L("MutedNotify", fl.lang:NiceTimeFull(player:GetNetVar("language"), math.Round(player:GetPlayerData("MuteOOC") - CurTime()))))

			return
		end

		chatbox.AddText(nil,
			Color("crimson"), "[LOOC]",
			hook.Run("ChatboxGetPlayerIcon", player, text, bTeamChat) or {},
			hook.Run("ChatboxGetPlayerColor", player, text, bTeamChat) or _team.GetColor(player:Team()),
			player,
			Color(config.Get("ic_color")),
			": ",
			text,
			{sender = player},
			position = player:GetPos(),
			radius = config.Get("talk_radius")
		)
	end)

	flPrefixes:AddPrefix({"/y ", "/s "}, function(player, text, bTeamChat)
		chatbox.AddText(nil,
			23,
			Color(config.Get("ic_color")),
			player:Name(),
			L("Chat_Yell"),
			hook.Run("ChatboxAdjustICText", text:Spelling()),
			position = player:GetPos(),
			radius = config.Get("talk_radius") * 2
		)
	end)

	flPrefixes:AddPrefix("/w ", function(player, text, bTeamChat)
		chatbox.AddText(nil,
			17,
			Color(config.Get("ic_color")),
			player:Name(),
			L("Chat_Whisper"),
			hook.Run("ChatboxAdjustICText", text:Spelling()),
			position = player:GetPos(),
			radius = config.Get("talk_radius") * 0.25
		)
	end)
end