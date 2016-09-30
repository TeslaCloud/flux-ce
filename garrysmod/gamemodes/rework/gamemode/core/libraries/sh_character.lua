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
	table.insert(stored[player:SteamID()], data);

	return CHAR_SUCCESS;
end;

if (SERVER) then
	function character.Load(player)
		stored[player:SteamID()] = stored[player:SteamID()] or {};

		rw.db:EasyRead("rw_characters", {"steamID", player:SteamID()}, function(result, hasData)
			if (hasData) then
				for k, v in ipairs(result) do
					stored[player:SteamID()][tonumber(v.uniqueID)] = plugin.Call("PreCharacterRestore", player, tonumber(v.uniqueID), stored[player:SteamID()]);
				end;
			end;

			plugin.Call("PostRestoreCharacters", player);
		end);
	end;

	function character.SaveAll(player)
		if (!IsValid(player)) then return; end;
		local toSave = plugin.Call("PreSaveCharacters", player, stored[player:SteamID()]) or stored[player:SteamID()];

		for k, v in ipairs(toSave) do
			rw.db:EasyWrite("rw_characters", {"steamID", player:SteamID(), "uniqueID", k}, v);
		end;

		plugin.Call("PostSaveCharacters", player);
	end;

	function character.Save(player, index)
		if (!IsValid(player) or typeof(index) != "number") then return; end;

		local toSave = plugin.Call("PreSaveCharacter", player, stored[player:SteamID()][index], index) or stored[player:SteamID()][index];
			rw.db:EasyWrite("rw_characters", {"steamID", player:SteamID(), "uniqueID", index}, toSave);
		plugin.Call("PostSaveCharacter", player, index);
	end;
end;

function playerMeta:GetActiveCharacter()
	return self:GetNetVar("ActiveCharacter", nil);
end;

function playerMeta:GetActiveCharacterTable()
	if (self:GetActiveCharacter()) then
		return stored[self:SteamID()][self:GetActiveCharacter()];
	end;
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