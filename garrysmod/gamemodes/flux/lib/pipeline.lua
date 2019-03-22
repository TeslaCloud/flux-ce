--[[
  Pipeline library lets you create systems that register their stuff via folders.
  It automatically does the boring stuff like converting filenames for you,
  requiring you to write the real thing only.
  Check out sh_item and sh_admin libraries for examples.
--]]

library 'Pipeline'

local stored = Pipeline.stored or {}
Pipeline.stored = stored

local last_pipe_aborted = false

function Pipeline.register(id, callback)
  stored[id] = {
    callback = callback,
    id = id
  }
end

function Pipeline.find(id)
  return stored[id]
end

function Pipeline.abort()
  last_pipe_aborted = true
end

function Pipeline.is_aborted()
  return last_pipe_aborted
end

function Pipeline.include(pipe, file_name)
  if isstring(pipe) then
    pipe = stored[pipe]
  end

  last_pipe_aborted = false

  if !pipe then return end
  if !isstring(file_name) then return end

  local extension = string.GetExtensionFromFilename(file_name) or ''
  local id = (string.GetFileFromFilename(file_name) or ''):gsub('%.'..extension, ''):to_id()

  if id:starts('cl_') or id:starts('sh_') or id:starts('sv_') then
    id = id:sub(4, id:len())
  end

  if id == '' then return end

  if isfunction(pipe.callback) then
    pipe.callback(id, file_name, pipe)
  end
end

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
