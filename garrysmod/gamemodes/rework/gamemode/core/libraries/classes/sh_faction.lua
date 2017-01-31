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

	table.insert(self.Ranks, {
		uniqueID = uniqueID,
		name = nameFilter
	});
end;

function CFaction:GenerateName(charName, rank)
	local finalName = self.NameTemplate;

	if (finalName:find("{name}")) then
		finalName = finalName:Replace("{name}", charName);
	end;

	if (finalName:find("{rank}")) then
		for k, v in ipairs(self.Ranks) do
			if (v.uniqueID == rank) then
				finalName = finalName:Replace("{rank}", v.name);
				break;
			end;
		end;
	end;

	for k, v in pairs(self.Data) do
		if (isstring(k)) then
			local key = k:utf8lower();

			if (finalName:find("{data:"..key.."}")) then
				finalName = finalName:Replace("{data:"..key.."}", v);
			end;
		end;
	end;

	return finalName;
end;

function CFaction:SetData(key, value)
	key = tostring(key);

	if (!key) then return; end;

	self.Data[key] = tostring(value);
end;

function CFaction:Register()
	faction.Register(self.uniqueID, self);
end;

function CFaction:__tostring()
	return "Faction ["..self.uniqueID.."]["..self.Name.."]";
end;

Faction = CFaction;