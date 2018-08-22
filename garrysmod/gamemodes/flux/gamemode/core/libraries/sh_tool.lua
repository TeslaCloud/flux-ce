--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]library.New("tool", fl)

local stored = fl.tool.stored or {}
fl.tool.stored = stored

function fl.tool:GetAll()
  return stored
end

function fl.tool:New(id)
  return CTool()
end

function fl.tool:Get(id)
  return stored[id]
end

function fl.tool:Register(obj)
  if (!obj) then return end

  obj:CreateConVars()
  stored[obj.Mode] = obj

  fl.DevPrint("Registering Tool: "..obj.Mode)
end

pipeline.Register("tool", function(id, fileName, pipe)
  TOOL = CTool()
  TOOL.Mode = id
  TOOL.id = id

  hook.Run("PreIncludeTool", TOOL)

  util.Include(fileName)

  hook.Run("ToolPreCreateConvars", TOOL)

  TOOL:CreateConVars()

  stored[id] = TOOL

  fl.DevPrint("Registering Tool: "..id)

  TOOL = nil
end)
