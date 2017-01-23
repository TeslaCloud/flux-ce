--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

if (!rw.fonts) then
	include("rework/gamemode/core/libraries/cl_fonts.lua");
end;

do
	local rwChatbox = {};

	function rwChatbox:CreateFonts()
		rw.fonts:CreateFont("reChatFont", {
			font		= "Roboto",
			size		= 17
		});

		rw.fonts:CreateFont("reChatFontBold", {
			font		= "Roboto",
			size		= 17,
			weight		= 1000
		});

		rw.fonts:CreateFont("reChatSyntax", {
			font		= "Roboto",
			size		= 20
		});
	end;

	function rwChatbox:OnResolutionChanged(newW, newH)
		chatbox.width = newW * 0.3;
		chatbox.height = newH * 0.3;
		chatbox.x = 4;
		chatbox.y = newH - chatbox.height - 36;

		chatbox.UpdateDisplay();

		if (chatbox.panel) then
			chatbox.panel:Remove();
			chatbox.panel = nil;
		end;
	end;

	plugin.AddHooks("ChatBoxHooks", rwChatbox);
end;

library.New("chatbox", _G);
chatbox.history 	= chatbox.history or {}; -- Entire chat history. Last X meesages, configurable.
chatbox.display		= chatbox.display or {}; -- Pre-parsed lines that are currently being drawn.
chatbox.filters 	= chatbox.filters or {}; -- Table that stores filter data.
chatbox.types 		= chatbox.types or {}; -- Table that stores message types data.
chatbox.emotes 		= chatbox.emotes or {} -- Table that stores emotes data.
chatbox.codes 		= chatbox.codes or {}; -- Table that stores BB-Codes data.

chatbox.oldAddText 	= chatbox.oldAddText or chat.AddText;

-- A function to add text to the chat box.
function chat.AddText(...)
	hook.Run("ChatAddText", ...);

	chatbox.AddText(...);
end;

function chatbox.GetLineCount()
	local lines = 0;

	for k, v in ipairs(chatbox.history) do
		lines = lines + (v.lineCount or 1);
	end;

	return lines;
end;

--[[
	Sizes and Configuration
--]]
chatbox.width = chatbox.width or ScrW() * 0.3;
chatbox.height = chatbox.height or ScrH() * 0.3;
chatbox.x = chatbox.x or 4;
chatbox.y = ScrH() - chatbox.height - 36;
chatbox.maxLength = chatbox.maxLength or 1024;
chatbox.curAlpha = chatbox.curAlpha or 255;

--[[
	Filters and Types
--]]

function chatbox.AddFilter(id, callback)
	if (!id or id == "") then return; end;

	chatbox.filters[id] = callback;
end;

function chatbox.AddType(id, callback)
	if (!id or id == "") then return; end;

	chatbox.types[id] = callback;
end;

function chatbox.GetFilter(id)
	if (!id or id == "") then return; end;

	if (chatbox.filters[id]) then
		return chatbox.filters[id];
	else
		return chatbox.filters["default"];
	end;
end;

function chatbox.GetType(id)
	if (!id or id == "") then return; end;

	if (chatbox.types[id]) then
		return chatbox.types[id];
	end;
end;

--[[
	Message table prototype:
	{
		text = string, -- text of the message
		playerName = string, -- name of the player who sent this message
		sender = plyObject, -- player object
		filter = string, -- filter id
		type = string, -- message type id
		icon = string, -- path to icon material. "" = no icon
		time = uint, -- time when the message has been added
		drawAvatar = bool, -- draw avatar or not
		drawTime = bool, -- draw time or not
		drawModel = bool, -- draw player model panel
		isPlayerMessage = bool, -- was this message sent by a valid player?
		sizeOverride = int, -- font size override
		rich = bool, -- force the bbcode parser on/off
		translate = bool -- whether or not to translate the message using #phrases system
	}

	display table prototype:
chatbox.display[1] = {
	[1] = { 0, LocalPlayer(), Color(255, 255, 255), "[SendTime:"..os.time().."]", "[icon:icon16/shield.png]", Color(255, 0, 0), "[SenderAvatar]", "[OOC] ", Color(255, 255, 255), "Mr. Meow: ", "Test message Test Message"},
	[2] = { 20, Color(255, 255, 255), "It is hardcoded btw. Render testing." }
}
--]]

do
	chatbox.AddFilter("default", function(messageData)
		messageData.drawAvatar = messageData.drawAvatar or false;
		messageData.drawTime = messageData.drawTime or true;
		messageData.drawModel = messageData.drawModel or false;
		messageData.isPlayerMessage = messageData.isPlayerMessage or false;
		messageData.rich = messageData.rich or true;
		messageData.translate = messageData.translate or true;
		messageData.type = messageData.type or "default";
	end);

	chatbox.AddFilter("system", function(messageData)
		-- system messages define this table themselves
		messageData.type = messageData.type or "system";
	end);

	chatbox.AddFilter("ooc", function(messageData)
		messageData.drawAvatar = true;
		messageData.drawTime = true;
		messageData.drawModel = false;
		messageData.isPlayerMessage = true;
		messageData.icon = "icon16/user.png";
		messageData.rich = true;
		messageData.translate = false;
		messageData.type = "ooc";
	end);

	chatbox.AddFilter("admin", function(messageData)
		messageData.drawAvatar = true;
		messageData.drawTime = true;
		messageData.drawModel = false;
		messageData.isPlayerMessage = true;
		messageData.icon = false;
		messageData.rich = true;
		messageData.translate = false;
		messageData.type = "admin";
	end);

	chatbox.AddFilter("ic", function(messageData)
		messageData.drawAvatar = false;
		messageData.drawTime = true;
		messageData.drawModel = true;
		messageData.isPlayerMessage = true;
		messageData.icon = "";
		messageData.rich = false;
		messageData.translate = false;
		messageData.type = "ic";
	end);

	chatbox.AddFilter("looc", function(messageData)
		messageData.drawAvatar = false;
		messageData.drawTime = true;
		messageData.drawModel = false;
		messageData.isPlayerMessage = true;
		messageData.icon = "icon16/user.png";
		messageData.rich = true;
		messageData.translate = false;
		messageData.type = "looc";
	end);

	chatbox.AddFilter("player_events", function(messageData)
		messageData.drawAvatar = false;
		messageData.drawTime = messageData.drawTime or true;
		messageData.drawModel = false;
		messageData.isPlayerMessage = false;

		if (messageData.icon == nil) then
			messageData.icon = "icon16/lightning.png";
		end;

		messageData.rich = true;
		messageData.translate = messageData.translate or true;
		messageData.type = "player_events";
	end);
end;

do
	chatbox.AddType("default", function(messageData)
		messageData.textColor = messageData.textColor or Color(255, 255, 255);
	end);

	chatbox.AddType("system", function(messageData)
		messageData.textColor = messageData.textColor or Color(255, 255, 255);
	end);

	chatbox.AddType("ooc", function(messageData)
		messageData.textColor = Color(255, 255, 255);
		messageData.prefix = "[OOC] ";
		messageData.prefixColor = Color(255, 20, 20);
	end);

	chatbox.AddType("admin", function(messageData)
		messageData.textColor = messageData.textColor or Color("#F0AAAA");
		messageData.prefix = messageData.prefix or "* [Admin Chat] ";
		messageData.prefixColor = Color(255, 20, 20);
	end);

	chatbox.AddType("pm", function(messageData)
		messageData.prefix = "[PM] ";
		messageData.prefixColor = Color("#65DBAC");
	end);

	chatbox.AddType("ic", function(messageData)
		messageData.textColor = messageData.textColor or Color(255, 255, 200);
	end);

	chatbox.AddType("player_events", function(messageData)
		messageData.textColor = messageData.textColor or Color("#EE4343");
		messageData.prefix = messageData.prefix or nil;
		messageData.prefixColor = messageData.prefixColor or Color(255, 20, 20);
	end);

	chatbox.AddType("looc", function(messageData)
		messageData.textColor = Color(255, 255, 255);
		messageData.prefix = "[LOOC] ";
		messageData.prefixColor = Color(255, 20, 20);
	end);
end;

--[[
	Emotes and BB-Codes
--]]

function chatbox.AddBBCode(id, callback, requireRich)
	if (!id or id == "") then return; end;

	chatbox.codes[id] = chatbox.codes[id] or {};
	chatbox.codes[id].Callback = callback;
	chatbox.codes[id].requireRich = requireRich or true;
end;

function chatbox.GetBBCode(id)
	if (chatbox.codes[id]) then
		return chatbox.codes[id].Callback;
	end;
end;

chatbox.LastBBCode = nil

function chatbox.ParseBBCodes(line, rich)
	if (chatbox.LastBBCode) then
		table.insert(line, 1, chatbox.LastBBCode);
	end;

	for k, v in ipairs(line) do
		if (typeof(v) == "string") then
			local whole = v;
			local length = whole:len();
			local hits = string.FindAll(v, "%b[]");
			local rm = false;
			local nextInsert = 0;
			local prevOffset = 0;

			if (#hits > 0) then
				for i, hit in ipairs(hits) do
					local text = hit[1];
					local wS, wE = hit[2], hit[3];
					local eq = text:find("=");
					local code = "";
					local eqWhat = "";
					local textValue = "";

					wS = wS - prevOffset;
					wE = wE - prevOffset;

					if (eq) then
						code = text:sub(2, eq - 1);
						eqWhat = text:sub(eq + 1, text:len() - 1);
					else
						code = text:sub(2, text:len() - 1);
					end;

					if (chatbox.codes[code]) then
						if (!chatbox.codes[code].requireRich or rich) then
							if (!rm) then
								table.remove(line, k);
								nextInsert = k;
								rm = true;
							end;

							local closure = {whole:find("%[", wE + 1)};
							local closurePos = closure[1];
							local oldTextLength = 0;

							if (closurePos) then
								textValue = whole:sub(wE + 1, closure[1] - 1);
							else
								textValue = whole:sub(wE + 1, length);
								closurePos = length;
							end;

							oldTextLength = textValue:len();

							local result, newTextValue = chatbox.GetBBCode(code)(eqWhat, textValue);

							if (typeof(newTextValue) == "string") then
								textValue = newTextValue;
							end;

							chatbox.LastBBCode = result;

							if (!whole:StartWith("[")) then
								table.insert(line, nextInsert, whole:sub(1, wS - 1));
								nextInsert = nextInsert + 1
							end;

							if (newTextValue) then
								length = length + (textValue:len() - oldTextLength);
								wS = wS + (textValue:len() - oldTextLength);
								wE = wE + (textValue:len() - oldTextLength);
							end;

							if (closurePos != length) then
								whole = textValue..whole:sub(closurePos, length);
							else
								whole = textValue;
							end;

							table.insert(line, nextInsert, result);
							nextInsert = nextInsert + 1;

							if (i == #hits) then
								table.insert(line, nextInsert, whole);
								nextInsert = nextInsert + 1;
								break;
							end;
						end;
					end;

					prevOffset = wE;
				end;
			end;
		end;
	end;
end;

do
	chatbox.AddBBCode("color", function(code, text)
		local exploded = string.Explode(",", code);

		for k, v in ipairs(exploded) do
			exploded[k] = v:Replace(" ", "");
		end;

		if (!exploded[2]) then
			local code = exploded[1];

			return Color(code);
		else
			return Color((tonumber(exploded[1]) or 255), (tonumber(exploded[2]) or 255), (tonumber(exploded[3]) or 255), (tonumber(exploded[4]) or 255));
		end;
	end);

	chatbox.AddBBCode("/color", function(code, text)
		return Color(255, 255, 255);
	end);
end;

--[[
	Text parser and renderer
--]]

function chatbox.WrapText(msgData, maxWidth, initWidth)
	local text = msgData.text;
	local wrapped = {};

	if (msgData.translate) then
		-- Attempt to translate the text before parsing.
		-- System messages often contain phrases, and line wrapping won't work unless we translate the
		-- phrases, duh.
		text = rw.lang:TranslateText(text);
	end;

	local parsed = {text};
	chatbox.ParseBBCodes(parsed, msgData.rich)

	local curWidth = initWidth or 0;
	local curText = "";
	local spaceWidth = util.GetTextSize(" ", "reChatFont");
	local dashWidth = util.GetTextSize("-", "reChatFont");

	for key, val in ipairs(parsed) do
		if (typeof(val) == "string") then
			local exploded = string.Explode(" ", val);

			for k, v in ipairs(exploded) do
				local w, h = util.GetTextSize(v, "reChatFont");

				-- if word's width is less than the remaining width
				if ((w + spaceWidth) < (maxWidth - curWidth)) then
					curText = curText..v.." ";
					curWidth = curWidth + w + spaceWidth;
				-- if it's exactly the width that's left
				elseif ((w + spaceWidth) == (maxWidth - curWidth) or w == (maxWidth - curWidth)) then
					curText = curText..v;
					table.insert(wrapped, curText);
					table.insert(wrapped, "std::endl");
					curText = "";
					curWidth = 0;
				-- if it's more
				else
					-- if the word doesn't fit in a single line
					if (w > maxWidth) then
						local characters = string.Explode("", v);
						local curWord = "";
						local wordWide = 0;

						for k2, v2 in ipairs(characters) do
							local w, h = util.GetTextSize(v2, "reChatFont");

							-- if we don't have enough characters to fill in the entire line
							if ((wordWide + w + dashWidth) < (maxWidth - curWidth)) then
								curWord = curWord..v2;
								wordWide = wordWide + w;
							-- if we do
							else
								curWord = curWord..v2.."-";
								curText = curText..curWord;
								table.insert(wrapped, curText);
								table.insert(wrapped, "std::endl");
								wordWide = 0;
								curWidth = 0;
								curText = "";
								curWord = "";
							end;
						end;

						if (curWord != "") then
							curText = curWord.." ";
						end;
					-- if it does
					else
						table.insert(wrapped, curText);
						table.insert(wrapped, "std::endl");
						curText = v.." ";
						curWidth = w + spaceWidth;
					end;
				end;
			end;

			table.insert(wrapped, curText);
			curText = "";
		else
			table.insert(wrapped, val);
		end;
	end;

	-- insert the leftover text.
	if (curText != "") then
		table.insert(wrapped, "std::endl");
		table.insert(wrapped, curText);
	end;

	return wrapped;
end;

g_DisplayY = g_DisplayY or 0;

function chatbox.ParseText(messageData)
	local parsed = {};
	local msgWidth = 0;

	messageData.filter = messageData.filter or "ooc";

	hook.Run("ChatboxPreProcess", messageData);

	chatbox.GetFilter(messageData.filter)(messageData);
	chatbox.GetType(messageData.type)(messageData);

	hook.Run("PreChatboxParse", messageData);

	parsed[1] = parsed[1] or {};
	table.insert(parsed[1], g_DisplayY);

	if (messageData.isPlayerMessage and IsValid(messageData.sender)) then
		table.insert(parsed[1], messageData.sender);
	end;

	if (messageData.drawTime) then
		-- I know this is STUPID as heck, but for some reason
		-- if we don't store the value beforehand Lua will throw
		-- the following error:
		-- [ERROR] gamemodes/clockwork/framework/libraries/client/cl_chatbox.lua:474: wrong number of arguments to 'insert'
		local color = Color(255, 255, 255);
		table.insert(parsed[1], color); -- this was line 474 from the error btw.
		table.insert(parsed[1], "[SendTime:"..messageData.time.."]");
		table.insert(parsed[1], " - ");
		msgWidth = msgWidth + 50;
	end;

	if (messageData.icon and messageData.icon != "") then
		table.insert(parsed[1], "[icon:"..messageData.icon.."]");
		msgWidth = msgWidth + 20;
	end;

	if (messageData.drawAvatar and IsValid(messageData.sender)) then
		if (!file.Exists("reavatars/"..messageData.sender:SteamID64()..".jpg", "DATA")) then
			if (!file.Exists("reavatars", "DATA")) then
				file.CreateDir("reavatars");
			end;

			http.Fetch("http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=76415A95E2F81DDA1D7CD2378D16C11D&steamids="..messageData.sender:SteamID64(), function(body)
				local response = util.JSONToTable(body);
				local avatarURL = response["response"]["players"][1].avatar;

				http.Fetch(avatarURL, function(avatarImage)
					file.Write("reavatars/"..messageData.sender:SteamID64()..".jpg", avatarImage);

					if (rw.core.MaterialCache[messageData.sender:SteamID64()..".jpg"]) then
						rw.core:ClearMaterial(messageData.sender:SteamID64()..".jpg");
					end;
				end);
			end);
		end;

		table.insert(parsed[1], "[SenderAvatar]");
		msgWidth = msgWidth + 20;
	end;

	if (messageData.prefix) then
		-- Prefix may contain phrases!
		messageData.prefix = rw.lang:TranslateText(messageData.prefix);

		table.insert(parsed[1], messageData.prefixColor);
		table.insert(parsed[1], messageData.prefix);

		local wide = util.GetTextSize(messageData.prefix, "reChatFont");
		msgWidth = msgWidth + wide;
	end;

	if (messageData.isPlayerMessage) then
		if (IsValid(messageData.sender)) then
			messageData.playerTeam = messageData.sender:Team();

			if (messageData.filter == "ic") then
				local plyName = messageData.sender:Name(); //CW.player:GetName(messageData.sender);

				if (plyName:utf8len() >= 40) then
					messageData.playerName = "["..plyName:utf8sub(1, 40).."...]";
				else
					messageData.playerName = plyName;
				end;
			else
				messageData.playerName = messageData.sender:Name();
			end;
		end;

		if (messageData.filter != "ic" and messageData.playerTeam) then
			table.insert(parsed[1], _team.GetColor(messageData.playerTeam));
		else
			table.insert(parsed[1], messageData.textColor);
		end;

		if (messageData.suffix) then
			-- Suffix too!
			messageData.suffix = rw.lang:TranslateText(messageData.suffix);
		end;

		table.insert(parsed[1], messageData.playerName..(messageData.suffix or ": "));

		local wide = util.GetTextSize(messageData.playerName..(messageData.suffix or ": "), "reChatFont");
		msgWidth = msgWidth + wide;
	end;

	if (messageData.text) then
		local wrapped = chatbox.WrapText(messageData, chatbox.width - 8, msgWidth);
		local curLine = 1;
		local bIsNew = true;

		for k, v in ipairs(wrapped) do
			parsed[curLine] = parsed[curLine] or {};

			if (curLine > 1) then
				table.insert(parsed[curLine], g_DisplayY)
			end;

			if (bIsNew) then
				table.insert(parsed[curLine], messageData.textColor);
				bIsNew = false;
			end;

			if (typeof(v) == "string") then
				if (v == "std::endl") then
					curLine = curLine + 1;

					parsed[curLine] = parsed[curLine] or {};

					bIsNew = true;
					v = "";
				end;
			end;

			if (v != "") then
				table.insert(parsed[curLine], v);
			end;
		end;
	end;

	chatbox.LastBBCode = nil;

	hook.Run("PostChatboxParse", parsed);

	return parsed;
end;

--[[
	Panels
--]]

local PANEL = {};
PANEL.isOpen = false;
PANEL.scrollOffset = 0;

local fadeDuration = 0.2;

function PANEL:Init()
	self.alpha = 0;

	self:SetSize(chatbox.width, chatbox.height);
	self:SetPos(chatbox.x, chatbox.y);

	self.scrollBar = vgui.Create("Panel", self);
	self.scrollBar:SetMouseInputEnabled(true);

	self.scrollBar.Think = function(sb)
		sb:SetSize(self:GetWide(), self:GetTall());
		sb:SetPos(0, 0);
	end;

	self.scrollBar.OnMouseWheeled = function(sb, delta)
		-- prettiest code contest 2k16 lmao
		self.scrollOffset = math.Clamp(self.scrollOffset + delta, 0, math.Clamp(chatbox.GetLineCount() - 19, 0, chatbox.GetLineCount()));
		chatbox.UpdateDisplay();
	end;
end;

function PANEL:SetChatOpen(bIsOpen)
	self.isOpen = bIsOpen;
	self.startTime = CurTime();
end;

local function IsIcon(text)
	return (text:StartWith("[icon:") and text:EndsWith(".png]"));
end;

local function IsAvatar(text)
	return (text == "[SenderAvatar]");
end;

local function IsTime(text)
	return (text:StartWith("[SendTime:"));
end;

local function SendTime(text)
	if (IsTime(text)) then
		return tonumber(text:sub(11, text:find("]") - 1));
	end;
end;

local function ToIcon(text)
	if (IsIcon(text)) then
		return text:sub(7, text:find("]") - 1);
	end;
end;

function PANEL:Paint(w, h)
	local backColor = rw.settings:GetColor("MenuBackColor");

	if (self.startTime) then
		local fraction = (CurTime() - self.startTime) / fadeDuration;

		if (self.isOpen) then
			self.alpha = Lerp(fraction, 0, backColor.a);
		else
			self.alpha = Lerp(fraction, backColor.a, 0);
		end;
	end;

	draw.RoundedBox(2, 0, 0, w, h, ColorAlpha(backColor, self.alpha));

	local curFont = "reChatFont";
	local curColor = Color(255, 255, 255);
	local offX = 4;
	local offY = 0;
	local curSender = nil;

	for k, v in ipairs(chatbox.display) do
		if ((os.time() - v._METADATA.time) < 8 or self.isOpen) then
			for k2, v2 in pairs(v) do
				if (typeof(v2) == "table") then
					if (k2 != "_METADATA") then
						v2.a = chatbox.curAlpha or v2.a or 255;
						curColor = v2;
					end;
				elseif (typeof(v2) == "string") then
					if (IsTime(v2)) then
						local time = os.date("%H:%M", SendTime(v2));

						draw.SimpleTextOutlined(time, curFont, offX, offY, curColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(60, 60, 60, chatbox.curAlpha))

						local width = util.GetTextSize(time, "reChatFont");
						offX = offX + width + 2;
					elseif (IsIcon(v2)) then
						local matPath = ToIcon(v2);
						local material = util.GetMaterial(matPath);

						surface.SetDrawColor(255, 255, 255, chatbox.curAlpha);
						surface.SetMaterial(material);
						surface.DrawTexturedRect(offX, offY, 16, 16);

						offX = offX + 18;
					elseif (IsAvatar(v2)) then
						if (IsValid(curSender)) then
							local matPath = ToIcon(v2);
							local material = Material("data/reavatars/"..curSender:SteamID64()..".jpg");

							surface.SetDrawColor(255, 255, 255, chatbox.curAlpha);
							surface.SetMaterial(material);
							surface.DrawTexturedRect(offX, offY, 16, 16);

							offX = offX + 18;
						end;
					else
						draw.SimpleTextOutlined(v2, curFont, offX, offY, curColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(60, 60, 60, chatbox.curAlpha))

						local width = util.GetTextSize(v2, "reChatFont");
						offX = offX + width;
					end;
				elseif (typeof(v2) == "number") then
					offY = v2;
					offX = 4;
				elseif (typeof(v2) == "player") then
					curSender = v2;
				else
					print(v2);
				end;
			end;
		end;
	end;

	if (chatbox.IsTypingCommand()) then
		local splitTable = string.Explode(" ", string.utf8sub(chatbox.GetCurrentText(), 2));
		local commands = {};
		local command = splitTable[1];
		local cX, cY = 4, h * 0.6;

		if (command and command != "") then
			chatbox.curAlpha = 50;

			for k, v in pairs(rw.command.aliases) do
				local commandLen = string.utf8len(command);

				if (commandLen == 0) then
					commandLen = 1;
				end;

				if (string.utf8sub(k, 1, commandLen) == string.lower(command) and (!splitTable[2] or string.lower(command) == k)) then
					local cmdTable = rw.command:Find(v);

 					if (cmdTable) then
 						local bShouldAdd = true;

 						-- It can so happen that multiple alias for the same command begin with the same string.
 						-- We don't want to display the same command multiple times, so we check for that.
 						for k, v in pairs(commands) do
 							if (v == cmdTable) then
 								bShouldAdd = false;
 							end;
 						end;

 						if (bShouldAdd) then
 							commands[#commands + 1] = cmdTable;
 						end;
 					end;
				end;

				if (#commands == 8) then
					break;
				end;
			end;

			for k, v in ipairs(commands) do
				cX = 4;
				draw.SimpleTextOutlined("/"..v.name, "reChatSyntax", cX, cY, Color(240, 240, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0));
				local w = util.GetTextSize("/"..v.name, "reChatSyntax");
				cX = cX + w + 8;
				draw.SimpleTextOutlined((v.tip or ""), "reChatFont", cX, cY + 4, Color(206, 206, 206), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0));

				if (#commands == 1) then
					local offsetX = 24;

					if (v.aliases) then
						local text = "#CMDDesc_Aliases ";

						if (#v.aliases > 1) then
							for i, a in ipairs(v.aliases) do
								text = text..a.."; ";
							end;
						else
							text = text..v.aliases[1];
						end;

						draw.SimpleTextOutlined(rw.lang:TranslateText(text), "reChatFont", 4, cY + offsetX, Color(240, 240, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0))

						offsetX = offsetX + 20;
					end;

					draw.SimpleTextOutlined(rw.lang:TranslateText("#CMDDesc_Usage ".."/"..v.name.." "..v.syntax), "reChatFont", 4, cY + offsetX, Color(240, 240, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0));
				end;

				cY = cY + 24;
			end;
		else
			chatbox.curAlpha = 255;
		end;
	else
		chatbox.curAlpha = 255;
	end;
end;

PANEL.NextAdjust = CurTime();

local lerpDuration = 0.15;

function PANEL:Think()
	local curTime = CurTime();

	if (curTime > self.NextAdjust) then
		hook.Run("AdjustChatboxInfo", chatbox);

		self.NextAdjust = curTime + (1 / 8);
	end;

	if (self.isOpen and input.IsKeyDown(KEY_ESCAPE)) then
		chatbox.Hide();
	end;
end;

vgui.Register("reChatBox", PANEL, "EditablePanel");

local PANEL = {};

function PANEL:Init()
	self:SetText("");
end;

local entryBack = Color(0, 0, 0, 170);

function PANEL:Paint(w, h)
	draw.RoundedBox(2, 0, 0, w, h, entryBack);

	self:DrawTextEntryText(rw.settings:GetColor("TextColor"), ColorAlpha(rw.settings:GetColor("TextColor"), 25), rw.settings:GetColor("TextColor"));
end;

function PANEL:OnEnter()
	local text = self:GetValue();

	netstream.Start("ChatboxTextEntered", text);

	hook.Run("ChatBoxTextTyped", text);

	self:SetText("");
	
	if (rw.tabMenu) then
		chatbox.textEntry:RequestFocus();
	end;
end;

function PANEL:Think()
	self:SetSize(chatbox.width, 24);
	self:SetPos(0, chatbox.height - 24);

	local maxChatLength = config.Get("max_chat_length") or 256;
	local text = self:GetValue();

	if (text and text != "") then
		if (string.utf8len(text) > maxChatLength) then
			self:SetValue(string.utf8sub(text, 0, maxChatLength));
		elseif (chatbox.IsOpen()) then
			if (text != self.previousText) then
				hook.Run("ChatBoxTextChanged", self.previousText or "", text);
			end;
		end;
	end;

	self.previousText = text;
end;

function PANEL:SetValue(text)
	self:SetText(text);

	if (text and text != "") then
		if (limit) then
			if (self:GetCaretPos() > string.utf8len(text)) then
				self:SetCaretPos(string.utf8len(text));
			end;
		else
			self:SetCaretPos(string.utf8len(text));
		end;
	end;
end;

function PANEL:OnKeyCodeTyped(code)
	if (code == KEY_ENTER and !self:IsMultiline() and self:GetEnterAllowed()) then
		self:FocusNext();
		self:OnEnter();
	else
		local text = hook.Run("ChatBoxKeyCodeTyped", code, self:GetValue());

		if (text and type(text) == "string") then
			self:SetValue(text);
		end;
	end;
end;

vgui.Register("reChatTextEntry", PANEL, "DTextEntry");

function chatbox.CreateChatBox()
	if (chatbox.panel) then
		chatbox.panel:Remove();
	end;

	chatbox.panel = vgui.Create("reChatBox");
end;

function chatbox.IsOpen()
	if (IsValid(chatbox.panel)) then
		return chatbox.panel.isOpen;
	end;
end;

-- A function to get the current text.
function chatbox.GetCurrentText()
	local textEntry = chatbox.textEntry;

	if (textEntry:IsVisible() and chatbox.IsOpen()) then
		return textEntry:GetValue();
	else
		return "";
	end;
end;

function chatbox.IsTypingOOC()
	local text = chatbox.GetCurrentText();

	return (text:StartWith("//") or text:StartWith(".//") or text:StartWith("[["));
end;

-- A function to get whether the player is typing a command.
function chatbox.IsTypingCommand()
	local text = chatbox.GetCurrentText();
	local prefix = {"/", "/?"};

	for k, v in pairs(prefix) do
		if (text:StartWith(v) and !chatbox.IsTypingOOC()) then
			return true;
		end;
	end;

	return false;
end;

function chatbox.CreateTextEntry()
	if (chatbox.textEntry) then
		chatbox.textEntry:Remove();
	end;

	chatbox.textEntry = vgui.Create("reChatTextEntry", chatbox.panel);
	chatbox.textEntry:SetFont("reChatFont");
	chatbox.textEntry:SetTextColor(Color(255, 255, 255));
end;

function chatbox.CreateDerma()
	chatbox.CreateChatBox();
	chatbox.CreateTextEntry();
end;

function chatbox.Show(panel)
	if (!chatbox.panel) then
		chatbox.CreateDerma();
	end;

	chatbox.panel:SetChatOpen(true);

	if (panel) then
		chatbox.panel:SetParent(panel);
	else
		chatbox.panel:MakePopup();
	end;

	chatbox.textEntry:AlphaTo(255, fadeDuration);
	chatbox.panel.scrollBar:AlphaTo(255, fadeDuration);
	chatbox.textEntry:RequestFocus();
	chatbox.lerpStart = CurTime();
end;

function chatbox.Hide()
	hook.Run("ChatBoxClosed", chatbox.GetCurrentText());

	chatbox.textEntry:AlphaTo(0, fadeDuration);
	chatbox.panel.scrollBar:AlphaTo(0, fadeDuration);

	chatbox.panel:SetChatOpen(false);
	chatbox.panel:SetMouseInputEnabled(false);
	chatbox.panel:SetKeyboardInputEnabled(false);

	hook.Run("FinishChat");
	timer.Simple(FrameTime() * 0.5, function() RunConsoleCommand("cancelselect") end)
end;

function chatbox.RecreatePanel()
	chatbox.panel:SetVisible(false);
	chatbox.textEntry:SetVisible(false);
	chatbox.textEntry:Remove();
	chatbox.panel.scrollBar:SetVisible(false);
	chatbox.panel.scrollBar:Remove()
	chatbox.panel:Remove();
	chatbox.panel = nil;
	chatbox.textEntry = nil;
	chatbox.CreateDerma();
end;

concommand.Add("rw_resetchat", chatbox.RecreatePanel)

function chatbox.UpdateDisplay()
	if (!chatbox.panel) then
		chatbox.CreateDerma();
	end;

	local i = 1;
	local textW, textH = util.GetTextSize("asdf1234", "reChatFont");
	local maxMessages = math.floor(chatbox.height * 0.85 / textH);

	g_DisplayY = (maxMessages - 2) * 20;
	chatbox.display = {};
	local curMsg = 0;

	for k, v in SortedPairs(chatbox.history, true) do
		if (curMsg < chatbox.panel.scrollOffset) then
			--nothing
		else
			if (i < maxMessages) then
				local parsed = chatbox.ParseText(chatbox.history[k]);

				for _, line in ipairs(parsed) do
					line._METADATA = {};
					line._METADATA.time = v.time;
					line._METADATA.index = k;

					if (#parsed > 1) then
						line._METADATA.multiLine = true;
					end;

					line._METADATA.lineCount = #parsed;
					chatbox.history[k].lineCount = #parsed;

					table.insert(chatbox.display, line);
				end;

				i = i + 1;
			else
				break;
			end;
		end;

		curMsg = curMsg + 1;
	end;

	local lastIdx = 0;
	local multiLineOffset = 0;
	local curLine = 1;

	for k, v in pairs(chatbox.display) do
		if (v._METADATA.index == lastIdx) then
			curLine = curLine + 1;

			v[1] = g_DisplayY + (curLine * 20);
		else
			multiLineOffset = 0;
			curLine = 1;

			if (v._METADATA.multiLine) then
				multiLineOffset = v._METADATA.lineCount * 20 - 20;

				v[1] = g_DisplayY - multiLineOffset;
				g_DisplayY = g_DisplayY - multiLineOffset - 20;

				lastIdx = v._METADATA.index;
			else
				v[1] = g_DisplayY;
				g_DisplayY = g_DisplayY - 20;
				lastIdx = v._METADATA.index;
			end;
		end;
	end;
end;

function chatbox.AddText(...)
	netstream.Start("ChatboxAddText", ...);
end;

--[[
	Hooks
--]]

hook.Add("PlayerBindPress", "chatbox.PlayerBindPress", function(player, bind, bPress)
	if ((string.find(bind, "messagemode") or string.find(bind, "messagemode2")) and bPress) then
		if (rw.client:HasInitialized()) then
			chatbox.Show();
		end;

		return true;
	end;
end);

hook.Add("GUIMousePressed", "chatbox.GUIMousePressed", function(mouseCode, aimVector)
	if (IsValid(chatbox.panel)) then
		chatbox.Hide();
	end;
end);

netstream.Hook("ChatboxTextEnter", function(player, messageData)
	if (IsValid(player)) then
		chat.PlaySound();

		print("["..messageData.filter:upper().."] "..player:Name()..": "..messageData.text);

		table.insert(chatbox.history, messageData);

		chatbox.UpdateDisplay();
		chatbox.Hide();
	end;
end);

netstream.Hook("ChatboxAddText", function(messageData)
	chat.PlaySound();

	print("["..messageData.filter:upper().."] "..messageData.text);

	table.insert(chatbox.history, messageData);

	chatbox.UpdateDisplay();
end);
