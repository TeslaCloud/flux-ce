--- The Pipeline library lets you create systems that register their stuff via folders.
-- It automatically does the boring stuff like converting filenames for you,
-- requiring you to write the real thing only.
-- Check out the sh_item and sh_admin libraries for examples.
mod 'Pipeline'

local stored = Pipeline.stored or {}
Pipeline.stored = stored

local last_pipe_aborted = false

--- Registers a new pipeline with the specified ID and callback.
-- The callback is called for every file included through the pipeline. It receives the ID
-- extracted from the file name, the path of the file and the pipeline's data table.
-- ```
-- Pipeline.register('item', function(id, file_name, pipe)
--   ITEM = ItemBase.new(id)
--
--   require_relative(file_name)
--
--   if Pipeline.is_aborted() then ITEM = nil return end
--
--   ITEM:register() ITEM = nil
-- end)
-- ```
-- @param id [String pipeline ID]
-- @param callback [Function called as callback(id, file_name, pipe)]
function Pipeline.register(id, callback)
  stored[id] = {
    callback = callback,
    id = id
  }
end

--- Find a pipeline with a specified ID. Case-sensitive.
-- @param id [String pipeline ID]
-- @return [Hash pipeline data, or nil if there is no such pipeline]
function Pipeline.find(id)
  return stored[id]
end

--- Aborts the current pipeline action. To be handled by callbacks individually.
function Pipeline.abort()
  last_pipe_aborted = true
end

--- Checks if the current pipeline has been aborted.
-- @return [Boolean is aborted]
function Pipeline.is_aborted()
  return last_pipe_aborted
end

do
  local filename_prefixes = {
    ['cl_'] = true,
    ['sh_'] = true,
    ['sv_'] = true
  }

  --- Include a filename using a specified pipeline.
  -- This automatically resolves server/client/shared realms,
  -- and automatically extracts the ID based on the filename
  -- (for example, "sh_test_file.lua" becomes "test_file" in the ID).
  -- After that if the pipe is a valid registered pipeline, the callback is called.
  -- @param pipe [String/Hash pipeline ID, or the pipeline data from Pipeline.find]
  -- @param file_name [String path of the file to include]
  function Pipeline.include(pipe, file_name)
    if isstring(pipe) then
      pipe = stored[pipe]
    end

    last_pipe_aborted = false

    if !pipe then return end
    if !isstring(file_name) then return end

    local extension = File.ext(file_name) or ''
    local id = (File.name(file_name) or ''):gsub('%.'..extension..'$', ''):to_id()
    local start = id:sub(1, 3)

    if filename_prefixes[start] then
      id = id:sub(4, id:len())
    end

    if id:len() == 0 then return end

    if isfunction(pipe.callback) then
      pipe.callback(id, file_name, pipe)
    end
  end
end

--- Include all files in a folder using a specific pipeline.
-- See documentation for `Pipeline.include`.
-- @param id [String pipeline ID]
-- @param directory [String folder relative to the LUA search path]
function Pipeline.include_folder(id, directory)
  local pipe = stored[id]

  if !pipe then return end

  if !directory:ends('/') then
    directory = directory..'/'
  end

  local files, dirs = _file.Find(directory..'*', 'LUA', 'namedesc')

  for k, v in ipairs(files) do
    Pipeline.include(pipe, directory..v)
  end
end
