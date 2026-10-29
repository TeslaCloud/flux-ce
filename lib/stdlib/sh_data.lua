--- Stores tables as JSON files on disk, for data that does not belong in the database. On the
-- server the files go to `settings/flux/` in the game folder, on the client to the `flux`
-- folder inside the `data` folder of the game. `Data.save`, `Data.load` and `Data.delete` take
-- a key that is the name of the file inside that folder. The `_schema` variants keep the data
-- apart for every schema and map, and the `_plugin` variants build on those for the data of
-- plugins, which is usually loaded in a `LoadData` handler and saved in a `SaveData` handler:
-- ```
-- function PLUGIN:LoadData()
--   self.texts = Data.load_plugin('3d_texts', {})
-- end
--
-- function PLUGIN:SaveData()
--   Data.save_plugin('3d_texts', self.texts)
-- end
-- ```
--
-- A key whose last part is the ID of a renamed plugin (see `Plugin.renamed`) and that has no
-- file is loaded from the file named after the old ID of the plugin, if there is one, and
-- `Flux.dev_print` names that file. Saving writes the file named after the current ID.

mod 'Data'

local isstring = isstring

local function schema_key(key)
  return 'schemas/'..Flux.schema..'/'..game.GetMap()..'/'..key
end

local function with_extension(key, extension)
  if !File.ext(key) then
    return key..extension
  end

  return key
end

--- Returns the key a file has under the old ID of a renamed plugin, for a key whose last part
-- is the current ID of that plugin.
-- @param key [String key with its extension]
-- @param exists [Function(key) that tells whether the file of a key exists]
-- @return [String the key under the old ID, nil if there is no such file]
local function renamed_key(key, exists)
  local renamed = Plugin?.renamed

  if !renamed then return end

  local folder, name, extension = key:match('^(.-)([^/]+)(%.[^./]+)$')

  if !name then return end

  for old_id, new_id in pairs(renamed) do
    if new_id == name then
      local old_key = folder..old_id..extension

      if exists(old_key) then
        Flux.dev_print("The '"..key.."' data file is read from '"..old_key.."', named after the old ID of the '"
          ..new_id.."' plugin.")

        return old_key
      end
    end
  end
end

if SERVER then
  local function server_file_exists(key)
    return file.Exists('settings/flux/'..key, 'GAME')
  end

  --- Saves a table to 'settings/flux/' in the game folder as JSON. The '.json' extension
  -- is added if the key does not have one. Does nothing unless the value is a table.
  -- @param key [String name of the file, can include folders]
  -- @param value [Map data to save]
  function Data.save(key, value)
    if !isstring(key) or !istable(value) then return end

    File.write('settings/flux/'..with_extension(key, '.json'), util.TableToJSON(value))
  end

  --- Loads a table saved with Data.save from 'settings/flux/'. Throws an error in development
  -- mode if the file does not exist and no default is specified.
  -- @param key [String name of the file, '.json' is added if it has no extension]
  -- @param default=nil [Any returned if the file does not exist]
  -- @return [Map the loaded data, or the default]
  function Data.load(key, default)
    if !isstring(key) then return end

    key = with_extension(key, '.json')

    if !server_file_exists(key) then
      key = renamed_key(key, server_file_exists) or key
    end

    local path = 'settings/flux/'..key

    if file.Exists(path, 'GAME') then
      return util.JSONToTable(File.read(path))
    elseif default != nil then
      return default
    elseif Flux.development then
      error_with_traceback("Attempt to load a data key that doesn't exist! ("..key..')')
    end
  end

  --- Deletes a file saved with Data.save from 'settings/flux/', if it exists.
  -- @param key [String name of the file, '.json' is added if it has no extension]
  function Data.delete(key)
    if !isstring(key) then return end

    local path = 'settings/flux/'..with_extension(key, '.json')

    if file.Exists(path, 'GAME') then
      File.delete(path)
    end
  end
else
  local function client_file_exists(key)
    return file.Exists('flux/'..key, 'DATA')
  end

  --- Saves a table to the 'flux' folder inside the client's 'data' folder as JSON. The '.dat'
  -- extension is added if the key does not have one. Does nothing unless the value is a table.
  -- @param key [String name of the file, can include folders]
  -- @param value [Map data to save]
  function Data.save(key, value)
    if !isstring(key) or !istable(value) then return end

    file.Write('flux/'..with_extension(key, '.dat'), util.TableToJSON(value))
  end

  --- Loads a table saved with Data.save from the 'flux' data folder. Throws an error
  -- in development mode if the file does not exist and no default is specified.
  -- @param key [String name of the file, '.dat' is added if it has no extension]
  -- @param default=nil [Any returned if the file does not exist]
  -- @return [Map the loaded data, or the default]
  function Data.load(key, default)
    if !isstring(key) then return end

    key = with_extension(key, '.dat')

    if !client_file_exists(key) then
      key = renamed_key(key, client_file_exists) or key
    end

    local path = 'flux/'..key

    if file.Exists(path, 'DATA') then
      return util.JSONToTable(file.Read(path, 'DATA'))
    elseif default != nil then
      return default
    elseif Flux.development then
      error_with_traceback("Attempt to load a data key that doesn't exist! ("..key..')')
    end
  end

  --- Lists the files inside a folder of the 'flux' data folder. Clientside only.
  -- @param folder [String]
  -- @return [List<String> file names, nil if the folder is not a string]
  function Data.get_files(folder)
    if !isstring(folder) then return end

    return (file.Find('flux/'..folder..'/*', 'DATA'))
  end

  --- Deletes a file saved with Data.save from the 'flux' data folder, if it exists.
  -- @param key [String name of the file, '.dat' is added if it has no extension]
  function Data.delete(key)
    if !isstring(key) then return end

    local path = 'flux/'..with_extension(key, '.dat')

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
  Data.save(schema_key(key), value)
end

--- Loads a table from the data folder of the current schema and map.
-- @param key [String]
-- @param default=nil [Any returned if the file does not exist]
-- @return [Map the loaded data, or the default]
-- @see [Data.load]
function Data.load_schema(key, default)
  return Data.load(schema_key(key), default)
end

--- Deletes a file from the data folder of the current schema and map.
-- @param key [String]
function Data.delete_schema(key)
  Data.delete(schema_key(key))
end

--- Saves plugin data. It is stored separately for every schema and map.
-- @param key [String]
-- @param value [Map data to save]
-- @see [Data.save]
function Data.save_plugin(key, value)
  Data.save_schema('plugins/'..key, value)
end

--- Loads plugin data saved with Data.save_plugin for the current schema and map.
-- ```
-- local loaded = Data.load_plugin('3d_texts', {})
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
  Data.delete_schema('plugins/'..key)
end
