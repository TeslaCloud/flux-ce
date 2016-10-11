--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("faction", _G);

local stored = faction.stored or {};
faction.stored = stored;

Class "Faction";

function Faction:Faction(id)
	self.uniqueID = id:MakeID();
end;

function Faction:Register()
	faction.Register(self.uniqueID, self);
end;

function faction.Register(id, data)
	if (!id or !data) then return; end;

	stored[id] = data;
end;