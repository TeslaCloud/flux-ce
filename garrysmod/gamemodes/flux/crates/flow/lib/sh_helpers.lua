-- A function to include a file based on it's prefix.
function require_relative(file_name)
  if !file_name:EndsWith('.lua') then
    file_name = file_name..'.lua'
  end

  if SERVER then
    if string.find(file_name, 'cl_') or file_name:EndsWith('/cl_init.lua') then
      return AddCSLuaFile(file_name)
    elseif !string.find(file_name, 'sv_') then
      AddCSLuaFile(file_name)
    end
  else
    if string.find(file_name, 'sv_') or string.find(file_name, 'cratespec') or file_name:EndsWith('/init.lua') then
      return
    end
  end

  return include(file_name)
end

-- A function to include all files in a directory.
function require_relative_folder(dir, base, recursive)
  if base then
    if isbool(base) then
      base = 'flux/gamemode/'
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
      if v:GetExtensionFromFilename() == 'lua' then
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
