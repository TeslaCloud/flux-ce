--[[
  Pipeline library lets you create systems that register their stuff via folders.
  It automatically does the boring stuff like converting filenames for you,
  requiring you to write the real thing only.
  Check out sh_item and sh_admin libraries for examples.
--]]

library.New "pipeline"

local stored = pipeline.stored or {}
pipeline.stored = stored

local lastPipeAborted = false

function pipeline.Register(id, callback)
  stored[id] = {
    callback = callback,
    id = id
  }
end

function pipeline.Find(id)
  return stored[id]
end

function pipeline.Abort()
  lastPipeAborted = true
end

function pipeline.IsAborted()
  return lastPipeAborted
end

function pipeline.Include(pipe, fileName)
  if (isstring(pipe)) then
    pipe = stored[pipe]
  end

  lastPipeAborted = false

  if (!pipe) then return end
  if (!isstring(fileName) or fileName:utf8len() < 7) then return end

  local id = (string.GetFileFromFilename(fileName) or ""):Replace(".lua", ""):to_id()

  if (id:StartWith("cl_") or id:StartWith("sh_") or id:StartWith("sv_")) then
    id = id:utf8sub(4, id:utf8len())
  end

  if (id == "") then return end

  if (isfunction(pipe.callback)) then
    pipe.callback(id, fileName, pipe)
  end
end

function pipeline.include_folder(id, directory)
  local pipe = stored[id]

  if (!pipe) then return end

  if (!directory:EndsWith("/")) then
    directory = directory.."/"
  end

  local files, dirs = _file.Find(directory.."*", "LUA", "namedesc")

  for k, v in ipairs(files) do
    pipeline.Include(pipe, directory..v)
  end
end
