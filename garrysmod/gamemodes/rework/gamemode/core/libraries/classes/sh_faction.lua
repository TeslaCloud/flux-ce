--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

Class "CFaction";

CFaction.Name = "Unknown Faction";
CFaction.Description = "This faction has no description set!";
CFaction.PhysDesc = "This faction has no default physical description set!";
CFaction.DefaultClass = nil;
CFaction.Color = Color(255, 255, 255);
CFaction.Models = {male = {}, female = {}, universal = {}};
CFaction.Classes = {};
CFaction.Ranks = {};
CFaction.Data = {};
CFaction.NameTemplate = "{rank} {name}";
-- You can also use {data:key} to insert data
-- set via Faction:SetData.

function CFaction:CFaction(id)
	self.uniqueID = id:MakeID();
end;

function CFaction:GetColor()
	return self.Color;
end;

function CFaction:GetName()
	return self.Name;
end;

function CFaction:GetData(key)
	return self.Data[key];
end;

function CFaction:GetDescription()
	return self.Description;
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

	if (!nameFilter) then nameFilter = uniqueID; end;

	table.insert(self.Ranks, {
		uniqueID = uniqueID,
		name = nameFilter
	});
end;

function CFaction:GenerateName(player, charName, rank, defaultData)
	defaultData = defaultData or {};

	if (hook.Run("ShouldNameGenerate", player, self, charName, rank, defaultData) == false) then return player:Name(); end;

	if (isfunction(self.MakeName)) then
		return self:MakeName(player, charName, rank, defaultData) or "John Doe";
	end;

	local finalName = self.NameTemplate;

	if (finalName:find("{name}")) then
		finalName = finalName:Replace("{name}", (charName or ""));
	end;

	if (finalName:find("{rank}")) then
		for k, v in ipairs(self.Ranks) do
			if (v.uniqueID == rank) then
				finalName = finalName:Replace("{rank}", v.name);
				break;
			end;
		end;
	end;

	local operators = string.FindAll(finalName, "{[%w]+:[%w]+}");

	for k, v in ipairs(operators) do
		if (v:StartWith("{callback:")) then
			local funcName = v:utf8sub(11, v:utf8len() - 1);
			local cb = self[funcName];

			if (isfunction(cb)) then
				finalName:Replace(v, cb(self, player));
			end;
		elseif (v:StartWith("{data:")) then
			local key = v:utf8sub(7, v:utf8len() - 1);
			local data = player:GetCharacterData(key, (defaultData[key] or self.Data[key] or ""));

			if (isstring(data)) then
				finalName:Replace(v, data);
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