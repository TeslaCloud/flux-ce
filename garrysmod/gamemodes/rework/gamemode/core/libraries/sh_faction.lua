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

	data.uniqueID = id:MakeID() or (data.Name and data.Name:MakeID());
	data.Name = data.Name or "Unknown Faction";
	data.Description = data.Description or "This faction has no description!";
	data.PrintName = data.PrintName or data.Name or "Unknown Faction";

	stored[id] = data;
end;

function faction.FindByID(id)
	return stored[id];
end;

function faction.Find(name, bStrict)
	for k, v in pairs(stored) do
		if (bStrict) then
			if (k:utf8lower() == name:utf8lower()) then
				return v;
			elseif (v.Name:utf8lower() == name:utf8lower()) then
				return v;
			end;
		else
			if (k:utf8lower():find(name:utf8lower())) then
				return v;
			elseif (v.Name:utf8lower():find(name:utf8lower())) then
				return v;
			end;
		end;
	end;

	return false;
end;

pipeline.Register("faction", function(uniqueID, fileName, pipe)
	FACTION = Faction(uniqueID);

	util.Include(fileName);

	FACTION:Register(); FACTION = nil;
end);

function faction.IncludeFactions(directory)
	return pipeline.IncludeDirectory("faction", directory);
end;