--- Extensions of the `File` library, which reads and writes files anywhere in the game folder.
-- The library itself comes from the `file` binary module that the server opens on startup.
-- This file replaces `File.write` with a version that creates missing folders, and adds
-- recursive listing, wrappers around the built-in `file` functions that always work in the
-- game folder, and aliases such as `File.rm`, `File.dir` and `File.is_folder`.

include 'sh_table.lua'

File = File or {}

File.old_write = File.old_write or File.write

--- Writes a string to a file, creating the missing folders of its path first.
-- The path is relative to the game folder (garrysmod/).
-- @param file_name [String file path, e.g. 'settings/flux/config.json']
-- @param file_contents [String contents to write]
function File.write(file_name, file_contents)
  local pieces = string.split(file_name, '/')
  local current_path = ''

  for k, v in ipairs(pieces) do
    if File.ext(v) != nil then
      break
    end

    current_path = current_path..v..'/'

    if !file.Exists(current_path, 'GAME') then
      File.mkdir(current_path)
    end
  end

  File.old_write(file_name, file_contents)
end

--- Lists all files inside of a folder and its subfolders.
-- Subfolders whose name starts with a dot are skipped.
-- @param folder [String folder path relative to the game folder]
-- @return [List<String> file paths, each one starting with the folder path]
function File.get_list(folder)
  folder = folder:ensure_end('/')
  local files, folders = file.Find(folder..'*', 'GAME')

  for k, v in ipairs(files) do
    files[k] = folder..v
  end

  for k, v in ipairs(folders) do
    if v:start_with('.') then continue end

    local file_list = File.get_list(folder..v..'/')

    for k, v in ipairs(file_list) do
      table.insert(files, v)
    end
  end

  local b = {}

  return table.map(files, function(v) if !b[v] then b[v] = true return v end end)
end

--- Creates a file if it does not exist yet, by appending an empty string to it.
-- @param filename [String file path relative to the game folder]
-- @return [Any return value of File.append]
function File.touch(filename)
  return File.append(filename, '')
end

--- Checks whether a file or folder exists.
-- @param filename [String path relative to the game folder]
-- @return [Boolean]
function File.exists(filename)
  return file.Exists(filename, 'GAME')
end

--- Finds the files and folders that match a wildcard.
-- @param filename [String path with a wildcard relative to the game folder, e.g. 'gamemodes/*']
-- @param sort='nameasc' [String sorting order: 'nameasc', 'namedesc', 'dateasc' or 'datedesc']
-- @return [List<String> file names, List<String> folder names]
function File.find(filename, sort)
  return file.Find(filename, 'GAME', sort)
end

--- Checks whether a path points to a folder.
-- @param filename [String path relative to the game folder]
-- @return [Boolean]
function File.is_dir(filename)
  return file.IsDir(filename, 'GAME')
end

--- Returns the size of a file.
-- @param filename [String file path relative to the game folder]
-- @return [Number size in bytes, -1 if the file does not exist]
function File.size(filename)
  return file.Size(filename, 'GAME')
end

--- Returns the time a file or folder was last modified at.
-- @param filename [String path relative to the game folder]
-- @return [Number UNIX timestamp, 0 if the file does not exist]
function File.time(filename)
  return file.Time(filename, 'GAME')
end

--- Returns the extension of a file name.
-- @param filename [String file name or path]
-- @return [String extension without the dot, or nil if there is none]
function File.ext(filename)
  return string.GetExtensionFromFilename(filename)
end

--- Returns the file name part of a path.
-- @param filename [String file path]
-- @return [String file name including its extension]
function File.name(filename)
  return string.GetFileFromFilename(filename)
end

--- Returns the folder part of a path.
-- @param filename [String file path]
-- @return [String path up to and including the last slash]
function File.path(filename)
  return string.GetPathFromFilename(filename)
end

--- Lists the names of the files and folders that match a wildcard as a single array.
-- @param path [String path with a wildcard relative to the game folder, e.g. 'gamemodes/*']
-- @param include_hidden=false [Boolean include entries whose name starts with a dot]
-- @return [List<String> file names followed by folder names, or nil if the search failed]
function File.ls(path, include_hidden)
  local files, folders = file.Find(path, 'GAME')

  if !files or !folders then return end

  table.Add(files, folders)

  return table.map(files, function(f)
    if include_hidden or !f:start_with('.') then
      return f
    end
  end)
end

File.rm               = File.delete
File.dir              = File.ls
File.create           = File.touch
File.remove           = File.delete
File.extension        = File.ext
File.is_folder        = File.is_dir
File.is_directory     = File.is_dir
File.make_directory   = File.mkdir
File.create_directory = File.mkdir
