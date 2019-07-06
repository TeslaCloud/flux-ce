library 'Data'

if SERVER then
  function Data.save(key, value)
    if !isstring(key) or !istable(value) then return end

    if !File.ext(key) then
      key = key..'.json'
    end

    File.write('settings/flux/'..key, util.TableToJSON(value))
  end

  function Data.load(key, default)
    if !isstring(key) then return end

    if !File.ext(key) then
      key = key..'.json'
    end

    if file.Exists('settings/flux/'..key, 'GAME') then
      return util.JSONToTable(File.read('settings/flux/'..key))
    elseif default != nil then
      return default
    else
      if Flux.development then
        error_with_traceback("Attempt to load data key that doesn't exist! ("..key..')')
      end
    end
  end

  function Data.delete(key)
    if !isstring(key) then return end

    if !File.ext(key) then
      key = key..'.json'
    end

    if file.Exists('settings/flux/'..key, 'GAME') then
      File.delete('settings/flux/'..key)
    end
  end
else
  function Data.save(key, value)
    if !isstring(key) or !istable(value) then return end

    if !File.ext(key) then
      key = key..'.dat'
    end

    file.Write('flux/'..key, util.TableToJSON(value))
  end

  function Data.load(key, default)
    if !isstring(key) then return end

    if !File.ext(key) then
      key = key..'.dat'
    end

    if file.Exists('flux/'..key, 'DATA') then
      return util.JSONToTable(file.Read('flux/'..key, 'DATA'))
    elseif default != nil then
      return default
    else
      if Flux.development then
        error_with_traceback("Attempt to load data key that doesn't exist! ("..key..')')
      end
    end
  end

  function Data.get_files(folder, default)
    if !isstring(folder) then return end

    local files, dirs = file.find('flux/'..folder..'/*', 'DATA')

    return files
  end

  function Data.delete(key)
    if !isstring(key) then return end

    if !File.ext(key) then
      key = key..'.dat'
    end

    if file.Exists('flux/'..key, 'DATA') then
      file.Delete('flux/'..key)
    end
  end
end

function Data.save_schema(key, value)
  return Data.save('schemas/'..Flux.get_schema_folder()..'/'..game.GetMap()..'/'..key, value)
end

function Data.load_schema(key, default)
  return Data.load('schemas/'..Flux.get_schema_folder()..'/'..game.GetMap()..'/'..key, default)
end

function Data.delete_schema(key)
  return Data.delete('schemas/'..Flux.get_schema_folder()..'/'..game.GetMap()..'/'..key)
end

function Data.save_plugin(key, value)
  return Data.save_schema('plugins/'..key, value)
end

function Data.load_plugin(key, default)
  return Data.load_schema('plugins/'..key, default)
end

function Data.delete_plugin(key)
  return Data.delete_schema('plugins/'..key)
end
