--- Stores tables as JSON files on disk, for data that does not belong in the database. On the
-- server the files go to `settings/flux/` in the game folder, on the client to the `flux`
-- folder inside the `data` folder of the game. `Data.save`, `Data.load` and `Data.delete` take
-- a key that is the name of the file inside that folder. The `_schema` variants keep the data
-- apart for every schema and map, and the `_plugin` variants build on those for the data of
-- plugins, which is usually loaded in a `LoadData` handler and saved in a `SaveData` handler:
-- ```
-- function PLUGIN:LoadData()
--   self.texts = Data.load_plugin('3dtexts', {})
-- end
--
-- function PLUGIN:SaveData()
--   Data.save_plugin('3dtexts', self.texts)
-- end
-- ```

mod 'Data'

local isstring = isstring

if SERVER then
  --- Saves a table to 'settings/flux/' in the game folder as JSON. The '.json' extension
  -- is added if the key does not have one. Does nothing unless the value is a table.
  -- @param key [String name of the file, can include folders]
  -- @param value [Map data to save]
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
  -- @return [Map the loaded data, or the default]
  function Data.load(key, default)
    if !isstring(key) then return end

    if !File.ext(key) then
      key = key..'.json'
    end

    local path = 'settings/flux/'..key

    if file.Exists(path, 'GAME') then
      return util.JSONToTable(File.read(path))
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

    local path = 'settings/flux/'..key

    if file.Exists(path, 'GAME') then
      File.delete(path)
    end
  end
else
  --- Saves a table to the 'flux' folder inside the client's 'data' folder as JSON. The '.dat'
  -- extension is added if the key does not have one. Does nothing unless the value is a table.
  -- @param key [String name of the file, can include folders]
  -- @param value [Map data to save]
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
  -- @return [Map the loaded data, or the default]
  function Data.load(key, default)
    if !isstring(key) then return end

    if !File.ext(key) then
      key = key..'.dat'
    end

    local path = 'flux/'..key

    if file.Exists(path, 'DATA') then
      return util.JSONToTable(file.Read(path, 'DATA'))
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
  -- @return [List<String> file names, nil if the folder is not a string]
  function Data.get_files(folder, default)
    if !isstring(folder) then return end

    local files, dirs = file.Find('flux/'..folder..'/*', 'DATA')

    return files
  end

  --- Deletes a file saved with Data.save from the 'flux' data folder, if it exists.
  -- @param key [String name of the file, '.dat' is added if it has no extension]
  function Data.delete(key)
    if !isstring(key) then return end

    if !File.ext(key) then
      key = key..'.dat'
    end

    local path = 'flux/'..key

    if file.Exists(path, 'DATA') then
      file.Delete(path)
    end
  end
end

--- Saves a table to the data folder of the current schema and map.
-- @param key [String]
-- @param value [Map data to save]
-- @see [Data.save]
function Data.save_schema(key, value)
  return Data.save('schemas/'..Flux.get_schema_folder()..'/'..game.GetMap()..'/'..key, value)
end

--- Loads a table from the data folder of the current schema and map.
-- @param key [String]
-- @param default=nil [Any returned if the file does not exist]
-- @return [Map the loaded data, or the default]
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
-- @param value [Map data to save]
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
-- @return [Map the loaded data, or the default]
-- @see [Data.load]
function Data.load_plugin(key, default)
  return Data.load_schema('plugins/'..key, default)
end

--- Deletes plugin data saved with Data.save_plugin for the current schema and map.
-- @param key [String]
function Data.delete_plugin(key)
  return Data.delete_schema('plugins/'..key)
end
