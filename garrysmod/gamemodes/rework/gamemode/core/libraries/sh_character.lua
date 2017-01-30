--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

library.New("character", _G);

if (rw.SchemaDisabled("characters")) then
	rw.core:DevPrint("Not loading characters system, disabled by schema.");
	return;
end;

local stored = character.stored or {};
character.stored = stored;

function character.Create(player, data)
	if (!isstring(data.name) or (data.name:utf8len() < config.Get("character_min_name_len") 
		or data.name:utf8len() > config.Get("character_max_name_len"))) then
		return CHAR_ERR_NAME;
	end;

	if (!isstring(data.physDesc) or (data.physDesc:utf8len() < config.Get("character_min_desc_len") 
		or data.physDesc:utf8len() > config.Get("character_max_desc_len"))) then
		return CHAR_ERR_DESC;
	end;

	if (!isnumber(data.gender) or (data.gender < CHAR_GENDER_MALE or data.gender > CHAR_GENDER_NONE)) then
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
					local prepared = {};
					prepared.steamID = player:SteamID();
					prepared.name = v.name;
					prepared.physDesc = v.physDesc;
					prepared.faction = v.faction;
					prepared.class = v.class or "";
					prepared.inventory = util.JSONToTable(v.inventory or "");
					prepared.ammo = util.JSONToTable(v.ammo or "");
					prepared.money = tonumber(v.money or "0");
					prepared.charPermissions = util.JSONToTable(v.charPermissions or "");
					prepared.data = util.JSONToTable(v.data or "");
					prepared.uniqueID = tonumber(v.uniqueID or k);
					prepared.key = v.key;

					stored[player:SteamID()][tonumber(v.uniqueID) or k] = prepared;
				end;
			end;

			character.SendToClient(player);

			hook.Run("PostRestoreCharacters", player);
		end);
	end;

	function character.SendToClient(player)
		netstream.Start(player, "rw_loadcharacters", stored[player:SteamID()]);
	end;

	function character.ToSaveable(player, char)
		local prepared = {};

		prepared.steamID = player:SteamID();
		prepared.name = char.name;
		prepared.physDesc = char.physDesc or "This character has no physical description set!";
		prepared.faction = char.faction or "player";
		prepared.class = char.class;
		prepared.model = char.model or "models/humans/group01/male_02.mdl";
		prepared.inventory = util.TableToJSON(char.inventory);
		prepared.ammo = util.TableToJSON(char.ammo);
		prepared.money= char.money;
		prepared.charPermissions = util.TableToJSON(char.charPermissions);
		prepared.data = util.TableToJSON(char.data);
		prepared.uniqueID = char.uniqueID;

		return prepared;
	end;

	function character.Save(player, index)
		if (!IsValid(player) or !isnumber(index) or hook.Run("PreSaveCharacter", player, index) == false) then return; end;

		local toSave = character.ToSaveable(player, stored[player:SteamID()][index]);
			rw.db:EasyWrite("rw_characters", {"uniqueID", index}, toSave);
		hook.Run("PostSaveCharacter", player, index);
	end;

	function character.SaveAll(player)
		if (!IsValid(player)) then return; end;

		for k, v in ipairs(stored[player:SteamID()]) do
			character.Save(player, k);
		end;
	end;

	function character.Get(player, index)
		if (stored[player:SteamID()][index]) then
			return stored[player:SteamID()][index];
		end
	end;

	function character.SetName(player, index, newName)
		local char = character.Get(player, index);

		if (char) then
			char.name = newName or char.name;

			player:SetNetVar("CharacterName", char.name);

			character.Save(player, index);
		end;
	end;
else
	netstream.Hook("rw_loadcharacters", function(data)
		stored[rw.client:SteamID()] = stored[rw.client:SteamID()] or {};
		stored[rw.client:SteamID()] = data;
	end);
end;

if (SERVER) then
	netstream.Hook("rw_debug_createchar", function(player, name)
		local data = {
			name = name,
			physDesc = "Default PhysDesc or something just to test it lol",
			gender = CHAR_GENDER_MALE,
			faction = "player",
			model = "models/humans/group01/male_02.mdl"
		};

		local status = character.Create(player, data);
		character.SendToClient(player);

		print("Created character: "..name);
	end);

	netstream.Hook("PlayerSelectCharacter", function(player, id)
		print(player:Name().." has loaded character #"..id);
		player:SetActiveCharacter(id);
	end);
end;

do
	local playerMeta = FindMetaTable("Player");

	function playerMeta:GetActiveCharacter()
		local charID = self:GetActiveCharacterID();

		if (charID) then
			return stored[self:SteamID()][charID];
		end;

		if (self:IsBot()) then
			self.charData = self.charData or {};

			return self.charData;
		end;
	end;

	function playerMeta:GetAllCharacters()
		return stored[self:SteamID()] or {};
	end;
end;