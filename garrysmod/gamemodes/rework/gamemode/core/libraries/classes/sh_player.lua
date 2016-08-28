--[[ 
	Do not share, re-distribute or sell.
--]]

local rePlayer = {};
rePlayer.DisplayName = "Rework Player";
DEFINE_BASECLASS("player_default");

-- Called when the data tables are setup.
function rePlayer:SetupDataTables()
	if (!self.Player or !self.Player.DTVar) then
		return;
	end;

	self.Player:DTVar("Bool", BOOL_INITIALIZED, "Initialized");
end;

player_manager.RegisterClass("rePlayer", rePlayer, "player_default");
