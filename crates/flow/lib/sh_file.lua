include 'sh_table.lua'

File = File or {}

File.old_write = File.old_write or File.write

function File.write(file_name, file_contents)
  local pieces = string.split(file_name, '/')
  local current_path = ''

  for k, v in ipairs(pieces) do
    if string.GetExtensionFromFilename(v) != nil then
      break
    end

    current_path = current_path..v..'/'

    if !file.Exists(current_path, 'GAME') then
      File.mkdir(current_path)
    end
  end

  File.old_write(file_name, file_contents)
end

function File.get_list(folder)
  folder = folder:ensure_end('/')
  local files, folders = file.Find(folder..'*', 'GAME')

  for k, v in ipairs(files) do
    files[k] = folder..v
  end

  for k, v in ipairs(folders) do
    if v:starts('.') then continue end

    local file_list = File.get_list(folder..v..'/')

    for k, v in ipairs(file_list) do
      table.insert(files, v)
    end
  end

  local b = {}

  return table.map(files, function(v) if !b[v] then b[v] = true return v end end)
end

function File.touch(filename)
  return File.append(filename, '')
end

File.rm               = File.delete
File.create           = File.touch
File.remove           = File.delete
File.make_directory   = File.mkdir
File.create_directory = File.mkdir
