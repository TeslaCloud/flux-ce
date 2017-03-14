--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("tool", fl)

local stored = fl.tool.stored or {}
fl.tool.stored = stored

function fl.tool:GetAll()
	return stored
end

function fl.tool:New(id)
	return flTool()
end

function fl.tool:Register(obj)
	if (!obj) then return end

	obj:CreateConVars()
	stored[obj.Mode] = obj

	fl.core:DevPrint("Registering Tool: "..obj.Mode)
end

pipeline.Register("tool", function(uniqueID, fileName, pipe)
	TOOL = flTool()
	TOOL.Mode = uniqueID
	TOOL.uniqueID = uniqueID

	util.Include(fileName)

	TOOL:CreateConVars()

	stored[uniqueID] = TOOL

	fl.core:DevPrint("Registering Tool: "..uniqueID)

	TOOL = nil
end)