--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

library.New("faction", _G);

local stored = faction.stored or {};
faction.stored = stored;

function faction.Register(id, data)
	if (!id or !data) then return; end;

	stored[id] = data;
end;