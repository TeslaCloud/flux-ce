--[[
	(C) TeslaCloud Studios LLC.
	For internal use only.
--]]

library.New("chatbox", _G);
chatbox.prefixes = chatbox.prefixes or {}; // Chatbox prefixes for serverside processing. Will be networked to clients for message styling.
chatbox.filters = chatbox.filters or {};

function chatbox.AddPrefix(prefix, callback)
	if (!prefix or prefix == "") then return; end;

	local oldCB = callback;

	function callback(msgData)
		oldCB(msgData);

		msgData.text = msgData.text:sub(prefix:len() + 1, msgData.text:len());
	end;

	chatbox.prefixes[prefix] = {};
	chatbox.prefixes[prefix].Callback = callback;
	chatbox.prefixes[prefix].length = prefix:len();
end;

function chatbox.GetPrefix(prefix)
	if (chatbox.prefixes[prefix]) then
		return chatbox.prefixes[prefix];
	end;
end;

function chatbox.AddFilter(id, callback)
	if (!id or id == "") then return; end;

	chatbox.filters[id] = callback;
end;

function chatbox.GetFilter(id)
	if (chatbox.filters[id]) then
		return chatbox.filters[id];
	end;
end;

function chatbox.CanHear(listener, position, radius)
	if (listener:HasInitialized()) then
		if (typeof(radius) != "number") then return false; end;
		if (radius == 0) then return true; end;
		if (radius < 0) then return false; end;

		if (position:Distance(listener:GetPos()) <= radius) then
			return true;
		end;
	end;

	return false;
end;

do
	chatbox.AddFilter("ooc", function(listener, msgData)
		return true; -- todo chat types blocking
	end);

	chatbox.AddFilter("pm", function(listener, msgData)
		return true;
	end);

	-- variables in these 2 filters are locals because we may wanna use them a bit later.
	chatbox.AddFilter("looc", function(listener, msgData)
		local pos = msgData.position;
		local rad = msgData.radius or config.Get("talk_radius") or 356;

		return chatbox.CanHear(listener, pos, rad);
	end);

	chatbox.AddFilter("ic", function(listener, msgData)
		pos = msgData.position;

		if (!pos and IsValid(msgData.sender)) then
			pos = msgData.sender:GetPos();
		end;

		local rad = msgData.radius or config.Get("talk_radius") or 356;

		return chatbox.CanHear(listener, pos, rad);
	end);

	chatbox.AddFilter("player_events", function(listener, msgData)
		local pos = msgData.position;
		local rad = msgData.radius or config.Get("talk_radius") or 356;

		return chatbox.CanHear(listener, pos, rad);
	end);

	chatbox.AddFilter("events", function(listener, msgData)
		return true;
	end);

	chatbox.AddFilter("admin", function(listener, msgData)
		return (listener:IsAdmin() or listener:IsUserGroup("operator"));
	end);

	chatbox.AddFilter("default", function(listener, msgData)
		return true;
	end);

	-- prevent commands from appearing in chatbox.
	chatbox.AddFilter("command", function(listener, msgData)
		return false;
	end);

	chatbox.AddFilter("command_no_announcement", function(listener, msgData)
		return false;
	end);

	chatbox.AddFilter("player_as_system", function(listener, msgData)
		return true;
	end);
end;

do
	chatbox.AddPrefix("//", function(msgData)
		local text = msgData.text;

		if (text:StartWith("//")) then
			msgData.filter = "ooc";
			msgData.radius = 0;

			while (text:StartWith("// ")) do
				text = "//"..text:utf8sub(4, text:utf8len());
			end;

			msgData.text = text;

			return true; -- tell the system that we set everything!
		end;
	end);

	chatbox.AddPrefix(".//", function(msgData)
		local text = msgData.text;

		if (text:StartWith(".//")) then
			msgData.filter = "looc";
			msgData.radius = config.Get("talk_radius") or 356; -- todo

			while (text:StartWith(".// ")) do
				text = ".//"..text:utf8sub(5, text:utf8len());
			end;

			msgData.text = text;

			return true;
		end;
	end);

	-- who the fuck even does [[ anyway
	chatbox.AddPrefix("[[", function(msgData)
		local text = msgData.text;

		if (text:StartWith("[[")) then
			msgData.filter = "looc";
			msgData.radius = config.Get("talk_radius") or 356; -- todo

			while (text:StartWith("[[ ")) do
				text = "[["..text:utf8sub(4, text:utf8len());
			end;

			msgData.text = text;

			return true;
		end;
	end);

	chatbox.AddPrefix("/", function(msgData)
		local text = msgData.text;

		if (string.IsCommand(text) and !text:StartWith("//")) then
			msgData.filter = "command";
			msgData.isCommand = true;
			msgData.radius = -1;

			return true;
		end;
	end);

	chatbox.AddPrefix("/?", function(msgData)
		local text = msgData.text;

		if (text:StartWith("/?")) then
			msgData.filter = "command_no_announcement";
			msgData.isCommand = true;
			msgData.isCommandSilent = true;
			msgData.radius = -1;

			return true;
		end;
	end);

	chatbox.AddPrefix("@", function(msgData)
		local text = msgData.text;

		if (text:StartWith("@")) then
			msgData.filter = "admin";
			msgData.radius = 0;

			return true;
		end;
	end);

	chatbox.AddPrefix("<sys>", function(msgData)
		local text = msgData.text;

		if (text:StartWith("<sys>")) then
			msgData.filter = "player_as_system";
			msgData.radius = 0;

			return true;
		end;
	end);
end;

function chatbox.PlayerCanHear(listener, messageData)
	if (!IsValid(listener)) then
		return messageData.filter != "ic";
	end;

	return chatbox.GetFilter(messageData.filter or "default")(listener, messageData);
end;

function chatbox.AddText(listeners, ...)
	local args = {...};
	local message = {
		text = "",
		filter = "default",
		icon = "icon16/information.png",
		time = os.time(),
		drawAvatar = false,
		drawTime = true,
		drawModel = false,
		isPlayerMessage = false,
		rich = true,
		translate = true,
		players = {}
	};

	if (listeners == nil) then
		listeners = _player.GetAll();
	end;

	local colored = false;
	local curColor = Color(255, 255, 255);

	for k, v in pairs(args) do
		if (typeof(v) == "string") then
			if (colored) then
				message.text = message.text.."[color="..curColor.r..","..curColor.g..","..curColor.b..","..curColor.a.."]";
			end;

			message.text = message.text..v;

			if (colored and v:lower():find("[/color]")) then
				colored = false;
			end;
		elseif (IsColor(v)) then
			if (colored) then
				message.text = message.text.."[/color]";
			end;

			message.text = message.text.."[color="..v.r..","..v.g..","..v.b..","..v.a.."]";

			colored = true;
			curColor = v;
		elseif (typeof(v) == "player") then
			message.text = message.text..v:Name();
			table.insert(message.players, v);
		elseif (typeof(v) == "table") then
			table.Merge(message, v);
		end;
	end;

	if (colored) then
		message.text = message.text.."[/color]";
	end;

	if (IsValid(listeners)) then
		message.position = message.position or listeners:GetPos();
	else
		if (IsValid(message.players[1])) then
			message.position = message.position or message.players[1]:GetPos();
		end;
	end;

	hook.Run("ChatAddText", listeners, message);

	print("[Chat::"..message.filter:upper().."] "..message.text);

	if (!IsValid(listeners)) then
		for k, v in ipairs(listeners) do
			if (chatbox.GetFilter(message.filter)(v, message)) then
				netstream.Start(v, "ChatboxAddText", message);
			end;
		end;
	else
		if (chatbox.GetFilter(message.filter)(listeners, message)) then
			netstream.Start(listeners, "ChatboxAddText", message);
		end;
	end;

	return message;
end;

function chatbox.SayAsPlayer(player, radius, ...)
	chatbox.AddText(nil, "\""..text.."\"", {sender = player, isPlayerMessage = true, filter = "ic", radius = radius, textColor = Color(255, 255, 200, 255)});
end;

netstream.Hook("ChatboxAddText", chatbox.AddText);

netstream.Hook("ChatboxTextEntered", function(player, msgText)
	if (!msgText or msgText == "") then return; end;
	if (!IsValid(player)) then
		print("[Catwork Debug] Player is not valid. How the heck did this happen doe?");
		return;
	end;

	local message = {
		text = msgText, -- text of the message
		playerName = player:Name(), -- name of the player who sent this message
		sender = player, -- player object
		filter = "ic", -- filter id
		time = os.time(),
		position = player:GetPos(),
		steamID = player:SteamID(),
		steamID64 = player:SteamID64()
	}

	if (hook.Run("PlayerSay", player, message.text) == "") then
		return;
	end;

	if (msgText:StartWith("//")) then
		chatbox.GetPrefix("//").Callback(message);
	else
		for k, v in pairs(chatbox.prefixes) do
			if (msgText:StartWith(k)) then
				if (v.Callback(message)) then
					break;
				end;
			end;
		end;
	end;

	local prefix = config.Get("command_prefixes")[1];
	local maxChatLength = config.Get("max_chat_length") or 256;
	local curTime = CurTime();

	if (string.utf8len(message.text) >= maxChatLength) then
		message.text = string.utf8sub(message.text, 1, maxChatLength);
		message.text = message.text.."...";
	end;

	hook.Run("ChatboxPlayerSay", player, message);

	local shouldSend = true;

	if (!shouldSend) then return; end;
	if (message.text == "" or message.text == " ") then return; end;

	print("["..message.filter:upper().."] "..player:Name()..": "..message.text);

	for k, v in ipairs(_player.GetAll()) do
		if (chatbox.GetFilter(message.filter)(v, message)) then
			netstream.Start(v, "ChatboxTextEnter", player, message);
		end;
	end;
end);