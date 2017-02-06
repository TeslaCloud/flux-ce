--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("tool", rw)

local stored = rw.tool.stored or {}
rw.tool.stored = stored

function rw.tool:GetAll()
	return stored;
end;

function rw.tool:New(id)
	return rwTool()
end

function rw.tool:Register(obj)
	if (!obj) then return end

	obj:CreateConVars()
	stored[obj.Mode] = obj

	rw.core:DevPrint("Registering Tool: "..obj.Mode)
end

pipeline.Register("tool", function(uniqueID, fileName, pipe)
	TOOL = rwTool()
	TOOL.Mode = uniqueID
	TOOL.uniqueID = uniqueID

	util.Include(fileName)

	TOOL:CreateConVars()

	stored[uniqueID] = TOOL

	rw.core:DevPrint("Registering Tool: "..uniqueID)

	TOOL = nil
end)