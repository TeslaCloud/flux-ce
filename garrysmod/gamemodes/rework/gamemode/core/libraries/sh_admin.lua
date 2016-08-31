--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

library.New("admin", rw);
local groups = {}; -- Usergroups data
local permissions = {}; -- Permission descriptions and other data
local players = {}; -- Compiled permissions for each player
local compilerCache = {};

function rw.admin:CreateGroup(id, data)
	if (type(id) != "string") then return; end;

	data.id = id;

	if (!stored[id]) then
		stored[id] = data;
	end;
end;

function rw.admin:AddPermission(id, category, data)
	if (!id) then return; end;

	category = category or "general";
	data.uniqueID = id;
	permissions[category] = permissions[category] or {};

	if (!permissions[category][id]) then
		permissions[category][id] = data;
	end;
end;

function rw.admin:PermissionFromCommand(cmdObj)
	if (!cmdObj) then return; end;

	local data = {};
		data.uniqueID = cmdObj.uniqueID or cmdObj.name:lower():gsub(" ", "_");
		data.description = cmdObj.description or "No description provided";
		data.category = cmdObj.category or "general";
		data.name = cmdObj.name or cmdObj.uniqueID;
	self:AddPermission(data.uniqueID, data.category, data);
end;

function rw.admin:CheckPermission(player, permission)
	local playerPermissions = players[player:SteamID()];

	if (playerPermissions) then
		return playerPermissions[permission];
	end;
end;

function rw.admin:GetGroupPermissions(id)
	if (groups[id]) then
		return groups[id].permissions;
	else
		return {};
	end;
end;

function rw.admin:HasPermission(player, permission)
	if (!IsValid(player)) then return true; end;

	local steamID = player:SteamID();

	if (players[steamID] and players[steamID][permID]) then
		return true;
	end;

	local netPerms = player:GetNetVar("rePermissions", {});

	if (netPerms and netPerms[permID]) then
		return true;
	end;

	return false;
end;

if (SERVER) then
	local function SetPermission(steamID, permID, value)
		players[steamID] = players[steamID] or {};
		players[steamID][permID] = value;
	end;

	local function DeterminePermission(steamID, permID, value)
		local permTable = compilerCache[steamID];

		permTable[permID] = permTable[permID] or PERM_NO;

		if (value == PERM_NO) then return; end;
		if (permTable[permID] == PERM_NEVER) then return; end;
		if (permTable[permID] == value) then return; end;

		if (value == PERM_NEVER) then
			permTable[permID] = PERM_NEVER;
			SetPermission(steamID, permID, false);

			return;
		elseif (value == PERM_ALLOW) then
			permTable[permID] = PERM_ALLOW;
			SetPermission(steamID, permID, true);

			return;
		end;

		permTable[permID] = PERM_ERROR;
		SetPermission(steamID, permID, false);
	end;

	function rw.admin:CompilePermissions(player)
		if (!IsValid(player)) then return; end;

		local steamID = player:SteamID();
		local userGroup = player:GetUserGroup();
		local secondaryGroups = player:GetSecondaryGroups();
		local playerPermissions = player:GetCustomPermissions();
		local groupPermissions = self:GetGroupPermissions(userGroup);

		compilerCache[steamID] = {};

		for k, v in pairs(groupPermissions) do
			DeterminePermission(steamID, k, v);
		end;

		for _, group in ipairs(secondaryGroups) do
			local permTable = self:GetGroupPermissions(group);

			for k, v in pairs(permTable) do
				DeterminePermission(steamID, k, v);
			end;
		end;

		for k, v in pairs(playerPermissions) do
			DeterminePermission(steamID, k, v);
		end;

		player:SetPermissions(players[steamID]);
		compilerCache[steamID] = nil;
	end;
end;