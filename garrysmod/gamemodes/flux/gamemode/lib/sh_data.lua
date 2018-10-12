library.new 'data'

if SERVER then
  function data.Save(key, value)
    if !isstring(key) or !istable(value) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.json'
    end

    fileio.Write('settings/flux/'..key, util.TableToJSON(value))
  end

  function data.Load(key, default)
    if !isstring(key) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.json'
    end

    if file.Exists('settings/flux/'..key, 'GAME') then
      local data = fileio.Read('settings/flux/'..key)

      return util.JSONToTable(data)
    elseif default != nil then
      return default
    else
      if fl.development then
        ErrorNoHalt("Attempt to load data key that doesn't exist! ("..key..')\n')
      end
    end
  end

  function data.Delete(key)
    if !isstring(key) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.json'
    end

    if file.Exists('settings/flux/'..key, 'GAME') then
      fileio.Delete('settings/flux/'..key)
    end
  end
else
  function data.Save(key, value)
    if !isstring(key) or !istable(value) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.dat'
    end

    file.Write('flux/'..key, util.TableToJSON(value))
  end

  function data.Load(key, default)
    if !isstring(key) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.dat'
    end

    if file.Exists('flux/'..key, 'DATA') then
      local data = file.Read('flux/'..key, 'DATA')

      return util.JSONToTable(data)
    elseif default != nil then
      return default
    else
      if fl.development then
        ErrorNoHalt("Attempt to load data key that doesn't exist! ("..key..')\n')
      end
    end
  end

  function data.Delete(key)
    if !isstring(key) then return end

    if !string.GetExtensionFromFilename(key) then
      key = key..'.dat'
    end

    if file.Exists('flux/'..key, 'DATA') then
      file.Delete('flux/'..key)
    end
  end
end

function data.SaveSchema(key, value)
  return data.Save('schemas/'..fl.get_schema_folder()..'/'..game.GetMap()..'/'..key, value)
end

function data.LoadSchema(key, failSafe)
  return data.Load('schemas/'..fl.get_schema_folder()..'/'..game.GetMap()..'/'..key, failSafe)
end

function data.DeleteSchema(key)
  return data.Delete('schemas/'..fl.get_schema_folder()..'/'..game.GetMap()..'/'..key)
end

function data.SavePlugin(key, value)
  return data.SaveSchema('plugins/'..key, value)
end

function data.LoadPlugin(key, failSafe)
  return data.LoadSchema('plugins/'..key, failSafe)
end

function data.DeletePlugin(key)
  return data.DeleteSchema('plugins/'..key)
end

_data = data
