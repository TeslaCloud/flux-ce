--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local playerMeta = FindMetaTable("Player");

if (SERVER) then
	function playerMeta:SetWhitelists(data)
		self:SetNetVar("whitelists", data);
	end;

	function playerMeta:SetData(data)
		self:SetNetVar("rwData", {});
	end;

	function playerMeta:SetInitialized(bIsInitialized)
		if (bIsInitialized == nil) then bIsInitialized = true; end;

		self:SetDTBool(BOOL_INITIALIZED, bIsInitialized);
	end;

	function playerMeta:Notify(message)
		rw.player:Notify(self, message)
	end;
end;

function playerMeta:HasInitialized()
	return self:GetDTBool(BOOL_INITIALIZED) or false;
end;

function playerMeta:GetData()
	return self:GetNetVar("rwData", {});
end;

function playerMeta:GetWhitelists()
	return self:GetNetVar("whitelists", {});
end;

playerMeta.rwName = playerMeta.rwName or playerMeta.Name;

function playerMeta:Name()
	if (character) then
		return self:GetNetVar("CharacterName", self:rwName());
	end;

	return self:rwName();
end;

function playerMeta:SteamName()
	return self:rwName();
end;

function playerMeta:SetModel(sPath)
	local oldModel = self:GetModel();

	plugin.Call("PlayerModelChanged", self, sPath, oldModel);

	if (SERVER) then
		netstream.Start(nil, "PlayerModelChanged", self:EntIndex(), sPath, oldModel);
	end;

	return self:rwSetModel(sPath);
end;