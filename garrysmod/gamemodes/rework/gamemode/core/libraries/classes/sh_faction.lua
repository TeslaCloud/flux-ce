--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

Class "CFaction";

CFaction.Name = "Unknown Faction";
CFaction.Description = "This faction has no description set!";
CFaction.Color = Color(255, 255, 255);
CFaction.Classes = {};
CFaction.Ranks = {};
CFaction.Data = {};
CFaction.NameTemplate = "{rank} {name}";
-- You can also use {data:key} to insert data
-- set via Faction:SetData.

function CFaction:CFaction(id)
	self.uniqueID = id:MakeID();
end;

function CFaction:AddClass(uniqueID, className, description, color, callback)
	if (!uniqueID) then return; end;

	self.Classes[uniqueID] = {
		name = className,
		description = description,
		color = color,
		callback = callback
	};
end;

function CFaction:AddRank(uniqueID, nameFilter)
	if (!uniqueID) then return; end;

	table.isnert(self.Ranks, {
		uniqueID = uniqueID,
		name = nameFilter
	});
end;

function CFaction:SetData(key, value)
	key = tostring(key);

	if (!key) then return; end;

	self.Data[key] = value;
end;

function CFaction:Register()
	faction.Register(self.uniqueID, self);
end;

Faction = CFaction;