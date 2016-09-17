--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local rePlayer = {};
rePlayer.DisplayName = "Rework Player";
DEFINE_BASECLASS("player_default");

local modelList = {};

for k, v in pairs(player_manager.AllValidModels()) do
	modelList[v:lower()] = k;
end;

-- Called when the data tables are setup.
function rePlayer:SetupDataTables()
	if (!self.Player or !self.Player.DTVar) then
		return;
	end;

	self.Player:DTVar("Bool", BOOL_INITIALIZED, "Initialized");
end;

-- Called on player spawn to determine which hand model to use.
function rePlayer:GetHandsModel()
	local playerModel = string.lower(self.Player:GetModel());
	local simpleName = nil;

	if (modelList[playerModel]) then
		return player_manager.TranslatePlayerHands(modelList[playerModel]);
	end;

	for k, v in pairs(modelList) do
		if (string.find(string.gsub(playerModel, "_", ""), v)) then
			modelList[playerModel] = v;

			break;
		end;
	end;

	return player_manager.TranslatePlayerHands(modelList[playerModel]);
end;

-- Called after view model is drawn.
function rePlayer:PostDrawViewModel(viewmodel, weapon)
	if (weapon.UseHands or !weapon:IsScripted()) then
		local handsEntity = rw.client:GetHands();
		
		if (IsValid(handsEntity)) then
			handsEntity:DrawModel();
		end;
	end;
end;

player_manager.RegisterClass("rePlayer", rePlayer, "player_default");