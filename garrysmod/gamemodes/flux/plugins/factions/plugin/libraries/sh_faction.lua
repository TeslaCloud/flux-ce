--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New "faction"

local stored = faction.stored or {}
faction.stored = stored

local count = faction.count or 0
faction.count = count

function faction.Register(id, data)
	if (!id or !data) then return end

	data.uniqueID = id:MakeID() or (data.Name and data.Name:MakeID())
	data.Name = data.Name or "Unknown Faction"
	data.Description = data.Description or "This faction has no description!"
	data.PrintName = data.PrintName or data.Name or "Unknown Faction"

	team.SetUp(count + 1, data.Name, data.Color or Color(255, 255, 255))

	data.teamID = count + 1

	stored[id] = data
	count = count + 1
end

function faction.FindByID(id)
	return stored[id]
end

function faction.Find(name, bStrict)
	for k, v in pairs(stored) do
		if (bStrict) then
			if (k:utf8lower() == name:utf8lower()) then
				return v
			elseif (v.Name:utf8lower() == name:utf8lower()) then
				return v
			end
		else
			if (k:utf8lower():find(name:utf8lower())) then
				return v
			elseif (v.Name:utf8lower():find(name:utf8lower())) then
				return v
			end
		end
	end

	return false
end

function faction.Count()
	return count
end

function faction.GetAll()
	return stored
end

pipeline.Register("faction", function(uniqueID, fileName, pipe)
	FACTION = Faction(uniqueID)

	util.Include(fileName)

	FACTION:Register() FACTION = nil
end)

function faction.IncludeFactions(directory)
	return pipeline.IncludeDirectory("faction", directory)
end

do
	local playerMeta = FindMetaTable("Player")

	function playerMeta:GetFactionID()
		return self:GetNetVar("faction", "player")
	end

	function playerMeta:GetFaction()
		return faction.FindByID(self:GetFactionID())
	end

	function playerMeta:GetRank()
		return self:GetCharacterData("Rank", -1)
	end

	function playerMeta:IsRank(strRank, bStrict)
		local factionTable = self:GetFaction()
		local rank = self:GetRank()

		if (rank != -1 and factionTable) then
			for k, v in ipairs(factionTable.Ranks) do
				if (string.utf8lower(v.uniqueID) == string.utf8lower(strRank)) then
					return (bStrict and k == rank) or k <= rank
				end
			end
		end

		return false
	end
end