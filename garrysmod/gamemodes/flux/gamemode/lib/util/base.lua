AddCSLuaFile()
include 'sh_string.lua'

-- A function to include a file based on it's prefix.
function util.include(file_name)
  if SERVER then
    if string.find(file_name, "cl_") then
      AddCSLuaFile(file_name)
    elseif string.find(file_name, "sv_") or string.find(file_name, "init.lua") then
      return include(file_name)
    else
      AddCSLuaFile(file_name)

      return include(file_name)
    end
  else
    if !string.find(file_name, "sv_") and file_name != "init.lua" and !file_name:ends("/init.lua") then
      return include(file_name)
    end
  end
end

-- A function to add a file to clientside downloads list based on it's prefix.
function util.add_cs_lua(file_name)
  if SERVER then
    if string.find(file_name, "sh_") or string.find(file_name, "cl_") or string.find(file_name, "shared.lua") then
      AddCSLuaFile(file_name)
    end
  end
end

-- A function to include all files in a directory.
function util.include_folder(dir, base, recursive)
  if base then
    if isbool(base) then
      base = "flux/gamemode/"
    elseif !base:ends("/") then
      base = base.."/"
    end

    dir = base..dir
  end

  if !dir:ends("/") then
    dir = dir.."/"
  end

  if recursive then
    local files, folders = _file.Find(dir.."*", "LUA", "namedesc")

    -- First include the files.
    for k, v in ipairs(files) do
      if v:GetExtensionFromFilename() == "lua" then
        util.include(dir..v)
      end
    end

    -- Then include all directories.
    for k, v in ipairs(folders) do
      util.include_folder(dir..v, recursive)
    end
  else
    local files, _ = _file.Find(dir.."*.lua", "LUA", "namedesc")

    for k, v in ipairs(files) do
      util.include(dir..v)
    end
  end
end
