library 'Flux::Tool'

Flux.Tool.stored = Flux.Tool.stored  or {}

function Flux.Tool:get(id)
  return self.stored[id]
end

Pipeline.register('tool', function(id, file_name, pipe)
  TOOL = Tool.new()
  TOOL.Mode = id
  TOOL.id = id

  hook.run('PreIncludeTool', TOOL)

  util.include(file_name)

  hook.run('ToolPreCreateConvars', TOOL)

  TOOL:CreateConVars()

  Flux.Tool.stored[id] = table.Copy(TOOL)

  Flux.dev_print('Registering Tool: '..id)

  TOOL = nil
end)
