--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

library.New("faction", _G);

local stored = faction.stored or {};
faction.stored = stored;

function faction.Register(id, data)
	if (!id or !data) then return; end;

	stored[id] = data;
end;