mod 'Flux::Tool'

Flux.Tool.stored = Flux.Tool.stored  or {}

--- Returns the tool with the specified ID.
-- @param id [String tool ID (the tool mode)]
-- @return [Tool the tool, or nil if there is no such tool]
function Flux.Tool:get(id)
  return self.stored[id]
end

Pipeline.register('tool', function(id, file_name, pipe)
  TOOL = Tool.new()
  TOOL.Mode = id
  TOOL.id = id

  hook.Run('PreIncludeTool', TOOL)

  require_relative(file_name)

  hook.Run('ToolPreCreateConvars', TOOL)

  TOOL:CreateConVars()

  Flux.Tool.stored[id] = table.Copy(TOOL)

  add_debug_metric('tools', id)

  TOOL = nil
end)
