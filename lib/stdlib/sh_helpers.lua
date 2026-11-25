--- File inclusion helpers built around `require_relative`, which includes a file and sends it
-- to clients as its name calls for.
-- The realm is taken from the file name: a file whose name starts with `cl_` is only sent to
-- clients, one whose name starts with `sv_` only runs on the server, and everything else is
-- shared. The names of the folders on the path do not matter.
-- `require_relative_folder` does the same for a whole folder, and `require_client`,
-- `require_server` and `require_shared` set the realm regardless of the name.

local should_ignore_client = false
local should_ignore_server = false

--- Ignore a certain realm in the require_relative function calls.
-- ```
-- require_ignore('server', true)
-- require_relative('sv_thing.lua') -- will not be included
-- require_ignore('server', false)
-- require_relative('sv_thing.lua') -- will be included
-- ```
-- @param who [String realm]
-- @param should_ignore [Boolean whether the realm should be ignored or not]
function require_ignore(who, should_ignore)
  who = who:lower()

  if who == 'server' or who == 'sv' then
    should_ignore_server = should_ignore
  else
    should_ignore_client = should_ignore
  end
end

--- Require a file relative to the current file's directory.
-- The .lua file ending may be omitted.
-- The realm is taken from the prefix of the file name (not of its folders), and the file is
-- sent to clients with AddCSLuaFile accordingly and automatically.
-- ```
-- require_relative 'cl_file'     -- will include cl_file.lua only on client
-- require_relative 'sv_file'     -- will include sv_file.lua only on server
-- require_relative 'file'        -- will include file.lua on both client and server
-- ```
-- @param file_name [String file to include]
-- @return [Object return value of include()]
function require_relative(file_name)
  if !file_name:EndsWith('.lua') then
    file_name ..= '.lua'
  end

  local prefix = file_name:match('[^/]*$'):sub(1, 3)

  if SERVER then
    if !should_ignore_client then
      if prefix == 'cl_' then
        return AddCSLuaFile(file_name)
      elseif prefix != 'sv_' then
        AddCSLuaFile(file_name)
      end
    end
  else
    if prefix == 'sv_' or
       string.find(file_name, 'packagespec', 1, true) or
       file_name:EndsWith('/init.lua') then
      return
    end
  end

  if SERVER and should_ignore_server then return end

  return include(file_name)
end

--- Require all files in a folder using require_relative.
-- `dir` is relative to the `LUA` search path unless `base` is given. A `base` of true stands
-- for the folder of the package being included, or `FLUX_PATH` outside of one. Files are
-- included in alphabetical order; when recursive, the subfolders follow them, also
-- alphabetically.
-- ```
-- require_relative_folder 'my_folder'
-- ```
-- @param dir [String folder to include]
-- @param base=nil [String/Boolean base folder for relativity, true for the current package]
-- @param recursive=false [Boolean include all files recursively]
-- @see [require_relative]
function require_relative_folder(dir, base, recursive)
  if base then
    if isbool(base) then
      base = PACKAGE and PACKAGE.__path__ or FLUX_PATH
    elseif !base:EndsWith('/') then
      base ..= '/'
    end

    dir = base..dir
  end

  if !dir:EndsWith('/') then
    dir ..= '/'
  end

  if recursive then
    local files, folders = file.Find(dir..'*', 'LUA', 'nameasc')

    for _, file_name in ipairs(files) do
      if File.ext(file_name) == 'lua' then
        require_relative(dir..file_name)
      end
    end

    for _, folder_name in ipairs(folders) do
      require_relative_folder(dir..folder_name, nil, recursive)
    end
  else
    local files, _ = file.Find(dir..'*.lua', 'LUA', 'nameasc')

    for _, file_name in ipairs(files) do
      require_relative(dir..file_name)
    end
  end
end

--- Require a clientside-only file.
-- The .lua file ending may be omitted.
-- This is the equivalent of simply doing this:
-- ```
-- if SERVER then
--   AddCSLuaFile(file_name)
-- else
--   include(file_name)
-- end
-- ```
-- @param file_name [String file name to include]
-- @return [Object return value of include()]
function require_client(file_name)
  if !file_name:EndsWith('.lua') then
    file_name ..= '.lua'
  end

  if SERVER then
    return AddCSLuaFile(file_name)
  else
    return include(file_name)
  end
end

--- Require a serverside-only file.
-- The .lua file ending may be omitted.
-- This is equivalent of simply doing this:
-- ```
-- if SERVER then
--   include(file_name)
-- end
-- ```
-- @param file_name [String file name to include]
-- @return [Object return value of include()]
function require_server(file_name)
  if !file_name:EndsWith('.lua') then
    file_name ..= '.lua'
  end

  if SERVER then
    return include(file_name)
  end
end

--- Require a file on both client and server.
-- The .lua file ending may be omitted.
-- This is equivalent of simply doing this:
-- ```
-- if SERVER then
--   AddCSLuaFile(file_name)
--   include(file_name)
-- else
--   include(file_name)
-- end
-- ```
-- @param file_name [String file name to include]
-- @return [Object return value of include()]
function require_shared(file_name)
  if !file_name:EndsWith('.lua') then
    file_name ..= '.lua'
  end

  if SERVER then
    AddCSLuaFile(file_name)
    return include(file_name)
  else
    return include(file_name)
  end
end
