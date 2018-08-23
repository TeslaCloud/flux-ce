function read_yaml(file_name)
  if file.Exists(file_name, 'GAME') then
    local local_name = file_name:gsub('%.y([a]?)ml', '.local.y%1ml')

    if file.Exists(local_name, 'GAME') then
      file_name = local_name
    end

    return fl.yaml.eval(file.Read(file_name, 'GAME'))
  end
end
