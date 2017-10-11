--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New "parameters"

local stored = parameters.stored or {}
parameters.stored = stored

function parameters.GetStored()
	return stored
end

function parameters.Register(uniqueID, data)
	if (!data) then return end

	if (!isstring(uniqueID) and !isstring(data.Name)) then
		ErrorNoHalt("[Flux] Attempt to register a parameter without a valid ID!")
		debug.Trace()

		return
	end

	if (!uniqueID) then
		uniqueID = data.Name:MakeID()
	end

	fl.DevPrint("Registering Parameter: "..tostring(uniqueID))

	data.uniqueID = uniqueID
	data.Name = data.Name or "Unknown Parameter"
	data.Default = data.Default or 0
	data.Min = data.Min or 0
	data.Max = data.Max or 100
	data.Decreases = data.Decreases or false
	data.Timer = data.Timer or 60
	data.BarData = data.BarData

	stored[uniqueID] = data
end

function parameters.FindByID(uniqueID)
	return stored[uniqueID]
end

function parameters.IncludeParameters(directory)
	pipeline.IncludeDirectory("parameter", directory)
end

pipeline.Register("parameter", function(uniqueID, fileName, pipe)
	PARAMETER = Parameter(uniqueID)

	util.Include(fileName)

	if (pipeline.IsAborted()) then PARAMETER = nil return end

	PARAMETER:Register() PARAMETER = nil
end)

do
	local playerMeta = FindMetaTable("Player")
end