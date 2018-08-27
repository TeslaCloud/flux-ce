library.new("tool", fl)

local stored = fl.tool.stored or {}
fl.tool.stored = stored

function fl.tool:GetAll()
  return stored
end

function fl.tool:New(id)
  return Tool.new()
end

function fl.tool:Get(id)
  return stored[id]
end

function fl.tool:register(obj)
  if (!obj) then return end

  obj:CreateConVars()
  stored[obj.Mode] = obj

  fl.dev_print("Registering Tool: "..obj.Mode)
end

pipeline.register("tool", function(id, file_name, pipe)
  TOOL = Tool.new()
  TOOL.Mode = id
  TOOL.id = id

  hook.run("PreIncludeTool", TOOL)

  util.include(file_name)

  hook.run("ToolPreCreateConvars", TOOL)

  TOOL:CreateConVars()

  stored[id] = TOOL

  fl.dev_print("Registering Tool: "..id)

  TOOL = nil
end)
