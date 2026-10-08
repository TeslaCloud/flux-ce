--- Loads and stores the tools of the tool gun. Sandbox only loads tools from the folder of its
-- tool gun entity, so Flux has a loader of its own: every file in the `tools` folder of Flux,
-- the schema or a plugin is included with a new `Tool` object in the `TOOL` global, the way a
-- Sandbox tool file expects it, and the resulting tool is stored under its mode, which is the
-- ID taken from the file name. `Flux.Tool:get` returns a stored tool.

mod 'Flux::Tool'

Flux.Tool.stored = Flux.Tool.stored or {}

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

  --- Called on the server and the client when a tool file is about to be included. The tool is
  -- a new `Tool` object that only has its mode and ID set.
  -- @param tool [Tool the tool that is being loaded]
  hook.Run('PreIncludeTool', TOOL)

  require_relative(file_name)

  --- Called on the server and the client after a tool file has been included, right before the
  -- console variables of the tool are created with `Tool:CreateConVars`.
  -- @param tool [Tool the tool that has been loaded]
  hook.Run('ToolPreCreateConvars', TOOL)

  TOOL:CreateConVars()

  Flux.Tool.stored[id] = table.Copy(TOOL)

  add_debug_metric('tools', id)

  TOOL = nil
end)
