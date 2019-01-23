library.new 'data'

if SERVER then
  function data.save(key, value)
    if !isstring(key) or !istable(value) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.json'
    end

    fileio.Write('settings/flux/'..key, util.TableToJSON(value))
  end

  function data.load(key, default)
    if !isstring(key) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.json'
    end

    if file.Exists('settings/flux/'..key, 'GAME') then
      return util.JSONToTable(fileio.Read('settings/flux/'..key))
    elseif default != nil then
      return default
    else
      if fl.development then
        ErrorNoHalt("Attempt to load data key that doesn't exist! ("..key..')\n')
      end
    end
  end

  function data.delete(key)
    if !isstring(key) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.json'
    end

    if file.Exists('settings/flux/'..key, 'GAME') then
      fileio.Delete('settings/flux/'..key)
    end
  end
else
  function data.save(key, value)
    if !isstring(key) or !istable(value) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.dat'
    end

    file.Write('flux/'..key, util.TableToJSON(value))
  end

  function data.load(key, default)
    if !isstring(key) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.dat'
    end

    if file.Exists('flux/'..key, 'DATA') then
      return util.JSONToTable(file.Read('flux/'..key, 'DATA'))
    elseif default != nil then
      return default
    else
      if fl.development then
        ErrorNoHalt("Attempt to load data key that doesn't exist! ("..key..')\n')
      end
    end
  end

  function data.get_files(folder, default)
    if !isstring(folder) then return end

    local files, dirs = file.find('flux/'..folder..'/*', 'DATA')
 
    return files
  end

  function data.delete(key)
    if !isstring(key) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.dat'
    end

    if file.Exists('flux/'..key, 'DATA') then
      file.Delete('flux/'..key)
    end
  end
end

function data.save_schema(key, value)
  return data.save('schemas/'..fl.get_schema_folder()..'/'..game.GetMap()..'/'..key, value)
end

function data.load_schema(key, default)
  return data.load('schemas/'..fl.get_schema_folder()..'/'..game.GetMap()..'/'..key, default)
end

function data.delete_schema(key)
  return data.delete('schemas/'..fl.get_schema_folder()..'/'..game.GetMap()..'/'..key)
end

function data.save_plugin(key, value)
  return data.save_schema('plugins/'..key, value)
end

function data.load_plugin(key, default)
  return data.load_schema('plugins/'..key, default)
end

function data.delete_plugin(key)
  return data.delete_schema('plugins/'..key)
end

_data = data
