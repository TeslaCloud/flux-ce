mod 'Data'

if SERVER then
  --- Saves a table to 'settings/flux/' in the game folder as JSON. The '.json' extension
  -- is added if the key does not have one. Does nothing unless the value is a table.
  -- @param key [String name of the file, can include folders]
  -- @param value [Hash data to save]
  function Data.save(key, value)
    if !isstring(key) or !istable(value) then return end

    if !File.ext(key) then
      key = key..'.json'
    end

    File.write('settings/flux/'..key, util.TableToJSON(value))
  end

  --- Loads a table saved with Data.save from 'settings/flux/'. Throws an error in development
  -- mode if the file does not exist and no default is specified.
  -- @param key [String name of the file, '.json' is added if it has no extension]
  -- @param default=nil [Any returned if the file does not exist]
  -- @return [Hash the loaded data, or the default]
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
        error_with_traceback("Attempt to load a data key that doesn't exist! ("..key..')')
      end
    end
  end

  --- Deletes a file saved with Data.save from 'settings/flux/', if it exists.
  -- @param key [String name of the file, '.json' is added if it has no extension]
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
  --- Saves a table to the 'flux' folder inside the client's 'data' folder as JSON. The '.dat'
  -- extension is added if the key does not have one. Does nothing unless the value is a table.
  -- @param key [String name of the file, can include folders]
  -- @param value [Hash data to save]
  function Data.save(key, value)
    if !isstring(key) or !istable(value) then return end

    if !File.ext(key) then
      key = key..'.dat'
    end

    file.Write('flux/'..key, util.TableToJSON(value))
  end

  --- Loads a table saved with Data.save from the 'flux' data folder. Throws an error
  -- in development mode if the file does not exist and no default is specified.
  -- @param key [String name of the file, '.dat' is added if it has no extension]
  -- @param default=nil [Any returned if the file does not exist]
  -- @return [Hash the loaded data, or the default]
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
        error_with_traceback("Attempt to load a data key that doesn't exist! ("..key..')')
      end
    end
  end

  --- Lists the files inside a folder of the 'flux' data folder. Clientside only.
  -- @param folder [String]
  -- @param default=nil [Any unused]
  -- @return [Array<String> file names, nil if the folder is not a string]
  function Data.get_files(folder, default)
    if !isstring(folder) then return end

    local files, dirs = file.find('flux/'..folder..'/*', 'DATA')

    return files
  end

  --- Deletes a file saved with Data.save from the 'flux' data folder, if it exists.
  -- @param key [String name of the file, '.dat' is added if it has no extension]
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

--- Saves a table to the data folder of the current schema and map.
-- @param key [String]
-- @param value [Hash data to save]
-- @see [Data.save]
function Data.save_schema(key, value)
  return Data.save('schemas/'..Flux.get_schema_folder()..'/'..game.GetMap()..'/'..key, value)
end

--- Loads a table from the data folder of the current schema and map.
-- @param key [String]
-- @param default=nil [Any returned if the file does not exist]
-- @return [Hash the loaded data, or the default]
-- @see [Data.load]
function Data.load_schema(key, default)
  return Data.load('schemas/'..Flux.get_schema_folder()..'/'..game.GetMap()..'/'..key, default)
end

--- Deletes a file from the data folder of the current schema and map.
-- @param key [String]
function Data.delete_schema(key)
  return Data.delete('schemas/'..Flux.get_schema_folder()..'/'..game.GetMap()..'/'..key)
end

--- Saves plugin data. It is stored separately for every schema and map.
-- @param key [String]
-- @param value [Hash data to save]
-- @see [Data.save]
function Data.save_plugin(key, value)
  return Data.save_schema('plugins/'..key, value)
end

--- Loads plugin data saved with Data.save_plugin for the current schema and map.
-- ```
-- local loaded = Data.load_plugin('3dtexts', {})
-- ```
-- @param key [String]
-- @param default=nil [Any returned if nothing has been saved yet]
-- @return [Hash the loaded data, or the default]
-- @see [Data.load]
function Data.load_plugin(key, default)
  return Data.load_schema('plugins/'..key, default)
end

--- Deletes plugin data saved with Data.save_plugin for the current schema and map.
-- @param key [String]
function Data.delete_plugin(key)
  return Data.delete_schema('plugins/'..key)
end
