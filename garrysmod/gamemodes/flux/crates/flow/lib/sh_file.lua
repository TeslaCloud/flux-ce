include 'sh_table.lua'

File = File or {}

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
