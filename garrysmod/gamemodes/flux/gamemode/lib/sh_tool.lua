library.new('tool', fl)

fl.tool.stored = fl.tool.stored  or {}

function fl.tool:get(id)
  return self.stored[id]
end

pipeline.register('tool', function(id, file_name, pipe)
  TOOL = Tool.new()
  TOOL.Mode = id
  TOOL.id = id

  hook.run('PreIncludeTool', TOOL)

  util.include(file_name)

  hook.run('ToolPreCreateConvars', TOOL)

  TOOL:CreateConVars()

  fl.tool.stored[id] = table.Copy(TOOL)

  fl.dev_print('Registering Tool: '..id)

  TOOL = nil
end)
