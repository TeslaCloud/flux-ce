DeriveGamemode('sandbox')

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

old_server_log = old_server_log or ServerLog

function ServerLog(...)
  old_server_log(...)
  print('')
end

function hook.run_client(player, strHookName, ...)
  Cable.send(player, 'fl_hook_run_cl', strHookName, ...)
end
