--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("character", _G)

if (fl.SchemaDisabled("characters")) then
	fl.core:DevPrint("Not loading characters system, disabled by schema.")

	return
end

local stored = character.stored or {}
character.stored = stored

function character.Create(player, data)
	if (!isstring(data.name) or (data.name:utf8len() < config.Get("character_min_name_len")
		or data.name:utf8len() > config.Get("character_max_name_len"))) then
		return CHAR_ERR_NAME
	end

	if (!isstring(data.physDesc) or (data.physDesc:utf8len() < config.Get("character_min_desc_len")
		or data.physDesc:utf8len() > config.Get("character_max_desc_len"))) then
		return CHAR_ERR_DESC
	end

	if (!isnumber(data.gender) or (data.gender < CHAR_GENDER_MALE or data.gender > CHAR_GENDER_NONE)) then
		return CHAR_ERR_GENDER
	end

	if (!isstring(data.model) or data.model == "") then
		return CHAR_ERR_MODEL
	end

	local steamID = player:SteamID()

	stored[steamID] = stored[steamID] or {}

	data.uniqueID = #stored[steamID] + 1

	table.insert(stored[steamID], data)

	if (SERVER) then
		character.Save(player, #stored[steamID])
	end

	return CHAR_SUCCESS
end

if (SERVER) then
	function character.Load(player)
		local steamID = player:SteamID()

		stored[steamID] = stored[steamID] or {}

		fl.db:EasyRead("fl_characters", {"steamID", steamID}, function(result, hasData)
			if (hasData) then
				for k, v in ipairs(result) do
					stored[steamID][tonumber(v.uniqueID) or k] = {
						steamID = steamID,
						name = v.name,
						physDesc = v.physDesc,
						faction = v.faction,
						class = v.class or "",
						inventory = util.JSONToTable(v.inventory or ""),
						ammo = util.JSONToTable(v.ammo or ""),
						money = tonumber(v.money or "0"),
						charPermissions = util.JSONToTable(v.charPermissions or ""),
						data = util.JSONToTable(v.data or ""),
						uniqueID = tonumber(v.uniqueID or k),
						key = v.key
					}
				end
			end

			character.SendToClient(player)

			hook.Run("PostRestoreCharacters", player)
		end)
	end

	function character.SendToClient(player)
		netstream.Start(player, "fl_loadcharacters", stored[player:SteamID()])
	end

	function character.ToSaveable(player, char)
		if (!IsValid(player) or !char) then return end

		return {
			steamID = player:SteamID(),
			name = char.name,
			physDesc = char.physDesc or "This character has no physical description set!",
			faction = char.faction or "player",
			class = char.class,
			model = char.model or "models/humans/group01/male_02.mdl",
			inventory = util.TableToJSON(char.inventory),
			ammo = util.TableToJSON(char.ammo),
			money= char.money,
			charPermissions = util.TableToJSON(char.charPermissions),
			data = util.TableToJSON(char.data),
			uniqueID = char.uniqueID
		}
	end

	function character.Save(player, index)
		if (!IsValid(player) or !isnumber(index) or hook.Run("PreSaveCharacter", player, index) == false) then return end

		local toSave = character.ToSaveable(player, stored[player:SteamID()][index])
			fl.db:EasyWrite("fl_characters", {"uniqueID", index}, toSave)
		hook.Run("PostSaveCharacter", player, index)
	end

	function character.SaveAll(player)
		if (!IsValid(player)) then return end

		for k, v in ipairs(stored[player:SteamID()]) do
			character.Save(player, k)
		end
	end

	function character.Get(player, index)
		local steamID = player:SteamID()

		if (stored[steamID][index]) then
			return stored[steamID][index]
		end
	end

	function character.SetName(player, index, newName)
		local char = character.Get(player, index)

		if (char) then
			char.name = newName or char.name

			player:SetNetVar("CharacterName", char.name)

			character.Save(player, index)
		end
	end
else
	netstream.Hook("fl_loadcharacters", function(data)
		stored[fl.client:SteamID()] = stored[fl.client:SteamID()] or {}
		stored[fl.client:SteamID()] = data
	end)
end

if (SERVER) then
	netstream.Hook("CreateCharacter", function(player, data)
		data.gender	= (data.gender and data.gender == "Female" and CHAR_GENDER_FEMALE) or CHAR_GENDER_MALE
		data.physDesc = data.description

		local status = character.Create(player, data)

		fl.core:DevPrint("Creating character. Status: "..status)

		if (status == CHAR_SUCCESS) then
			character.SendToClient(player)
			netstream.Start(player, "PlayerCreatedCharacter", true, status)

			fl.core:DevPrint("Success")
		else
			netstream.Start(player, "PlayerCreatedCharacter", false, status)

			fl.core:DevPrint("Error")
		end
	end)

	netstream.Hook("PlayerSelectCharacter", function(player, id)
		fl.core:DevPrint(player:Name().." has loaded character #"..id)

		player:SetActiveCharacter(id)
	end)
end

do
	local playerMeta = FindMetaTable("Player")

	function playerMeta:GetCharacter()
		local charID = self:GetActiveCharacterID()

		if (charID) then
			return stored[self:SteamID()][charID]
		end

		if (self:IsBot()) then
			self.charData = self.charData or {}

			return self.charData
		end
	end

	function playerMeta:GetAllCharacters()
		return stored[self:SteamID()] or {}
	end
end