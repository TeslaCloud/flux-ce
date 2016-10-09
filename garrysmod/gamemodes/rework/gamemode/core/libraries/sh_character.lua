--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("character", _G);

if (rw.SchemaDisabled("characters")) then
	rw.core:DevPrint("Not loading characters system, disabled by schema.");
	return;
end;

local stored = character.stored or {};
character.stored = stored;

local playerMeta = FindMetaTable("Player");

function character.Create(player, data)
	if (typeof(data.name) != "string" or (data.name:len() < rw.config:Get("character_min_name_len") 
		or data.name:len() > rw.config:Get("character_max_name_len"))) then
		return CHAR_ERR_NAME;
	end;

	if (typeof(data.physDesc) != "string" or (data.physDesc:len() < rw.config:Get("character_min_desc_len") 
		or data.physDesc:len() > rw.config:Get("character_max_desc_len"))) then
		return CHAR_ERR_DESC;
	end;

	if (typeof(data.gender) != "number" or (data.gender < CHAR_GENDER_MALE or data.gender > CHAR_GENDER_NONE)) then
		return CHAR_ERR_GENDER;
	end;

	stored[player:SteamID()] = stored[player:SteamID()] or {};

	data.uniqueID = #stored[player:SteamID()] + 1;

	table.insert(stored[player:SteamID()], data);

	if (SERVER) then
		character.Save(player, #stored[player:SteamID()]);
	end;

	return CHAR_SUCCESS;
end;

if (SERVER) then
	function character.Load(player)
		stored[player:SteamID()] = stored[player:SteamID()] or {};

		rw.db:EasyRead("rw_characters", {"steamID", player:SteamID()}, function(result, hasData)
			if (hasData) then
				for k, v in ipairs(result) do
					stored[player:SteamID()][tonumber(v.uniqueID) or k] = plugin.Call("PreCharacterRestore", player, tonumber(v.uniqueID) or k, v);
				end;
			end;

			character.SendToClient(player);

			plugin.Call("PostRestoreCharacters", player);
		end);
	end;

	function character.SendToClient(player)
		netstream.Start(player, "rw_loadcharacters", stored[player:SteamID()]);
	end;

	function character.SaveAll(player)
		if (!IsValid(player)) then return; end;
		local toSave = plugin.Call("PreSaveCharacters", player, stored[player:SteamID()]) or stored[player:SteamID()];

		for k, v in ipairs(toSave) do
			rw.db:EasyWrite("rw_characters", {"uniqueID", k}, v);
		end;

		plugin.Call("PostSaveCharacters", player);
	end;

	function character.Save(player, index)
		if (!IsValid(player) or typeof(index) != "number") then return; end;

		local toSave = plugin.Call("PreSaveCharacter", player, stored[player:SteamID()][index], index) or stored[player:SteamID()][index];
			rw.db:EasyWrite("rw_characters", {"uniqueID", index}, toSave);
		plugin.Call("PostSaveCharacter", player, index);
	end;
else
	netstream.Hook("rw_loadcharacters", function(data)
		stored[rw.client:SteamID()] = stored[rw.client:SteamID()] or {};
		stored[rw.client:SteamID()] = data;
	end);
end;

function playerMeta:GetActiveCharacter()
	return self:GetNetVar("ActiveCharacter", nil);
end;

function playerMeta:GetActiveCharacterTable()
	if (self:GetActiveCharacter()) then
		return stored[self:SteamID()][self:GetActiveCharacter()];
	end;
end;

function playerMeta:GetAllCharacters()
	return stored[self:SteamID()] or {};
end;

function playerMeta:SetActiveCharacter(id)
	self:SetNetVar("ActiveCharacter", (id or nil));
	plugin.Call("OnActiveCharacterSet", self);
end;

if (SERVER) then
	function playerMeta:SetCharacterData(key, value)
		local charData = self:GetActiveCharacterTable();

		if (!charData) then return; end;

		charData.data = charData.data or {};
		charData.data[key] = value;

		self:SetNetVar("CharacterData", charData.data);
	end;
end;

function playerMeta:GetCharacterData(key, default)
	return self:GetNetVar("CharacterData", {})[key] or default;
end;

if (SERVER) then
	netstream.Hook("rw_debug_createchar", function(player, name)
		local data = {
			name = name,
			physDesc = "Default PhysDesc or something just to test it lol",
			gender = CHAR_GENDER_MALE,
			faction = "default"
		}

		local status = character.Create(player, data);
		print(status)
		character.SendToClient(player);

		print("Created character: "..name);
	end);

	netstream.Hook("rw_selectchar", function(player, id)
		print(player:Name().." has loaded character #"..id);
		player:SetActiveCharacter(id);
	end);
end;