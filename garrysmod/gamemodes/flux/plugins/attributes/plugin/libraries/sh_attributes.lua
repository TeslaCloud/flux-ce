--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New "attributes"

local stored = attributes.stored or {}
attributes.stored = stored

local types = attributes.types or {}
attributes.types = types

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

	fl.DevPrint("Registering "..string.lower(data.Type)..": "..tostring(uniqueID))

	data.uniqueID = uniqueID
	data.Name = data.Name or "Unknown Attribute"
	data.Description = data.Description or "This attribute has no description!"
	data.Max = data.Max or 100
	data.Min = data.Min or 0
	data.Category = data.Category or "#Attribute_Category_Other"
	data.Icon = data.Icon
	data.Type = data.Type
	data.Multipliable = data.Multipliable or true
	data.Boostable = data.Boostable or true

	stored[uniqueID] = data
end

function attributes.FindByID(uniqueID)
	return stored[uniqueID]
end

function attributes.RegisterType(id, globalVar, folder)
	types[id] = globalVar

	plugin.add_extra(id)

	attributes.IncludeType(id, globalVar, folder)

	fl.DevPrint("Registering attribute type: ["..id.."] ["..globalVar.."] ["..folder.."]")
end

function attributes.IncludeType(id, globalVar, folder)
	pipeline.Register(id, function(uniqueID, fileName, pipe)
		_G[globalVar] = Attribute(uniqueID)

		util.Include(fileName)

		if (pipeline.IsAborted()) then _G[globalVar] = nil return end

		_G[globalVar].Type = globalVar
		_G[globalVar]:Register()
		_G[globalVar] = nil
	end)

	pipeline.IncludeDirectory(id, folder)
end

do
	local player_meta = FindMetaTable("Player")

	function player_meta:GetAttributes()
		return self:GetNetVar("attributes", {})
	end

	function player_meta:GetAttribute(uniqueID, bNoBoost)
		local attribute = attributes.FindByID(uniqueID)
		local attsTable = self:GetAttributes()

		if (!attsTable[uniqueID]) then
			return attribute.Min
		end

		local value = attsTable[uniqueID].value

		if (!bNoBoost and attribute.Boostable) then
			value = value + self:GetAttributeBoost(uniqueID)
		end

		return value
	end

	function player_meta:GetAttributeMultiplier(uniqueID)
		local attribute = self:GetAttributes()[uniqueID]

		if (attribute.multiplierExpires >= CurTime()) then
			return attribute.multiplier or 1
		else
			return 1
		end
	end

	function player_meta:GetAttributeBoost(uniqueID)
		local attribute = self:GetAttributes()[uniqueID]

		if (attribute.boostExpires >= CurTime()) then
			return attribute.boost or 0
		else
			return 0
		end
	end

	if (SERVER) then
		function player_meta:SetAttribute(uniqueID, value)
			local attsTable = self:GetAttributes()
			local attribute = attributes.FindByID(uniqueID)

			if (!attsTable[uniqueID]) then
				attsTable[uniqueID] = {}
			end

			attsTable[uniqueID].value = math.Clamp(value, attribute.Min, attribute.Max)

			self:SetNetVar("attributes", attsTable)
		end

		function player_meta:IncreaseAttribute(uniqueID, value, bNoMultiplier)
			local attribute = attributes.FindByID(uniqueID)
			local attsTable = self:GetAttributes()

			if (!bNoMultiplier) then
				value = value * self:GetAttributeMultiplier(uniqueID)

				if (value < 0) then
					value = value / self:GetAttributeMultiplier(uniqueID)
				end
			end

			attsTable[uniqueID].value = math.Clamp(attsTable[uniqueID].value + value, attribute.Min, attribute.Max)

			self:SetNetVar("attributes", attsTable)
		end

		function player_meta:DecreaseAttribute(uniqueID, value, bNoMultiplier)
			self:IncreaseAttribute(uniqueID, -value, bNoMultiplier)
		end

		function player_meta:AttributeMultiplier(uniqueID, value, duration)
			local attribute = attributes.FindByID(uniqueID)

			if (!attribute.Multipliable) then return end
			if (value <= 0) then return end

			local curTime = CurTime()
			local attsTable = self:GetAttributes()
			local expires = attsTable[uniqueID].multiplierExpires

			attsTable[uniqueID].multiplier = value

			if (expires and expires >= curTime) then
				attsTable[uniqueID].multiplierExpires = expires + duration
			else
				attsTable[uniqueID].multiplierExpires = curTime + duration
			end

			self:SetNetVar("attributes", attsTable)
		end

		function player_meta:BoostAttribute(uniqueID, value, duration)
			local attribute = attributes.FindByID(uniqueID)

			if (!attribute.Multipliable) then return end

			local curTime = CurTime()
			local attsTable = self:GetAttributes()
			local expires = attsTable[uniqueID].boostExpires

			attsTable[uniqueID].boost = value

			if (expires and expires >= curTime) then
				attsTable[uniqueID].boostExpires = expires + time
			else
				attsTable[uniqueID].boostExpires = curTime + time
			end

			self:SetNetVar("attributes", attsTable)
		end
	end
end
