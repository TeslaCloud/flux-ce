AddCSLuaFile()

local should_ignore_client = false
local should_ignore_server = false

function require_ignore(who, should_ignore)
  who = who:lower()

  if who == 'server' or who == 'sv' then
    should_ignore_server = should_ignore
  else
    should_ignore_client = should_ignore
  end
end

-- A function to include a file based on it's prefix.
function require_relative(file_name)
  if !file_name:EndsWith('.lua') then
    file_name = file_name..'.lua'
  end

  if SERVER then
    if !should_ignore_client then
      if string.find(file_name, 'cl_', 1, true) or file_name:EndsWith('/cl_init.lua') then
        return AddCSLuaFile(file_name)
      elseif !string.find(file_name, 'sv_', 1, true) then
        AddCSLuaFile(file_name)
      end
    end
  else
    if string.find(file_name, 'sv_', 1, true) or string.find(file_name, 'cratespec', 1, true) or file_name:EndsWith('/init.lua') then
      return
    end
  end

  if SERVER and should_ignore_server then return end

  return include(file_name)
end

-- A function to include all files in a directory.
function require_relative_folder(dir, base, recursive)
  if base then
    if isbool(base) then
      base = CRATE and CRATE.__path__ or 'flux/'
    elseif !base:EndsWith('/') then
      base = base..'/'
    end

    dir = base..dir
  end

  if !dir:EndsWith('/') then
    dir = dir..'/'
  end

  if recursive then
    local files, folders = _file.Find(dir..'*', 'LUA', 'namedesc')

    -- First include the files.
    for k, v in ipairs(files) do
      if File.ext(v) == 'lua' then
        require_relative(dir..v)
      end
    end

    -- Then include all directories.
    for k, v in ipairs(folders) do
      require_relative_folder(dir..v, recursive)
    end
  else
    local files, _ = _file.Find(dir..'*.lua', 'LUA', 'namedesc')

    for k, v in ipairs(files) do
      require_relative(dir..v)
    end
  end
end
