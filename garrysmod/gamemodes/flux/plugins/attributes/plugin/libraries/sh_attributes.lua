--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New "attributes"

local stored = attributes.stored or {}
attributes.stored = stored

function attributes.GetStored()
	return stored
end

function attributes.GetAll()
	local attsTable = {}

	for k, v in pairs(stored) do
		attsTable[#attsTable + 1] = k
	end

	return attsTable
end

function attributes.Register(uniqueID, data)
	if (!data) then return end

	if (!isstring(uniqueID) and !isstring(data.Name)) then
		ErrorNoHalt("[Flux] Attempt to register an attribute without a valid ID!")
		debug.Trace()

		return
	end

	if (!uniqueID) then
		uniqueID = data.Name:MakeID()
	end

	fl.DevPrint("Registering Attribute: "..tostring(uniqueID))

	data.uniqueID = uniqueID
	data.Name = data.Name or "Unknown Attribute"
	data.Description = data.Description or "This attribute has no description!"
	data.Maximum = data.Maximum or 100
	data.Minimum = data.Minimum or 0
	data.Category = data.Category or "#Attribute_Category_Other"
	data.Icon = data.Icon

	stored[uniqueID] = data
end

function attributes.FindByID(uniqueID)
	return stored[uniqueID]
end

function attributes.IncludeAttributes(directory)
	pipeline.IncludeDirectory("attribute", directory)
end

pipeline.Register("attribute", function(uniqueID, fileName, pipe)
	ATTRIBUTE = Attribute(uniqueID)

	util.Include(fileName)

	if (pipeline.IsAborted()) then ATTRIBUTE = nil return end

	ATTRIBUTE:Register() ATTRIBUTE = nil
end)

do
	local playerMeta = FindMetaTable("Player")

	function playerMeta:GetAttributes()
		return self:GetNetVar("attributes", {})
	end

	function playerMeta:GetAttribute(uniqueID, bNoBoost)
		local value = self:GetAttributes()[uniqueID].value

		if (!bNoBoost) then
			value = value + self:GetAttributeBoost(uniqueID)
		end

		return value or attributes.FindByID(uniqueID).Minimum
	end

	function playerMeta:GetAttributeMultiplier(uniqueID)
		local attribute = self:GetAttributes()[uniqueID]

		if (attribute.multiplierExpires >= CurTime()) then
			return attribute.multiplier or 1
		else
			return 1
		end
	end

	function playerMeta:GetAttributeBoost(uniqueID)
		local attribute = self:GetAttributes()[uniqueID]

		if (attribute.boostExpires >= CurTime()) then
			return attribute.boost or 0
		else
			return 0
		end
	end

	if (SERVER) then
		function playerMeta:SetAttribute(uniqueID, value)
			local attsTable = self:GetAttributes()

			if (!attsTable[uniqueID]) then
				attsTable[uniqueID] = {}
			end

			attsTable[uniqueID].value = value

			self:SetNetVar("attributes", attsTable)
		end

		function playerMeta:IncreaseAttribute(uniqueID, value, bNoMultiplier)
			local attsTable = self:GetAttributes()

			if (!bNoMultiplier) then
				value = value * self:GetAttributeMultiplier(uniqueID)

				if (value < 0) then
					value = value / self:GetAttributeMultiplier(uniqueID)
				end
			end

			if (!attsTable[uniqueID]) then
				attsTable[uniqueID] = {}
			end

			attsTable[uniqueID].value = attsTable[uniqueID].value + value

			self:SetNetVar("attributes", attsTable)
		end

		function playerMeta:DecreaseAttribute(uniqueID, value, bNoMultiplier)
			self:IncreaseAttribute(uniqueID, -value, bNoMultiplier)
		end

		function playerMeta:AttributeMultiplier(uniqueID, value, duration)
			local curTime = CurTime()
			local attsTable = self:GetAttributes()

			if (!attsTable[uniqueID]) then
				attsTable[uniqueID] = {}
			end

			attsTable[uniqueID].multiplier = value

			local expires = attsTable[uniqueID].multiplierExpires

			if (expires and expires >= curTime) then
				attsTable[uniqueID].multiplierExpires = expires + duration
			else
				attsTable[uniqueID].multiplierExpires = curTime + duration
			end

			self:SetNetVar("attributes", attsTable)
		end

		function playerMeta:BoostAttribute(uniqueID, value, duration)
			local curTime = CurTime()
			local attsTable = self:GetAttributes()

			if (!attsTable[uniqueID]) then
				attsTable[uniqueID] = {}
			end

			attsTable[uniqueID].boost = value

			local expires = attsTable[uniqueID].boostExpires

			if (expires and expires >= curTime) then
				attsTable[uniqueID].boostExpires = expires + time
			else
				attsTable[uniqueID].boostExpires = curTime + time
			end

			self:SetNetVar("attributes", attsTable)
		end
	end
end