AddCSLuaFile()

--- Prints a message to the console. Tables are printed with PrintTable.
-- @param message [Any]
function Flux.print(message)
  if !istable(message) then
    print(message)
  else
    PrintTable(message)
  end
end

--- Prints a debug message to the console, but only in development or when the
-- debug_output_in_production setting is enabled.
-- @param message [String]
function Flux.dev_print(message)
  if Flux.development or Settings.debug_output_in_production then
    Msg('Debug: ')
    MsgC(Color(200, 200, 200), message)
    Msg('\n')
  end
end

file.old_write = file.old_write or file.Write

--- Writes a file to the data/ folder. This detour of the engine function also creates all
-- of the folders leading to the file. The original function is kept as file.old_write.
-- @param file_name [String path of the file, relative to data/]
-- @param contents [String]
function file.Write(file_name, contents)
  local pieces = file_name:split('/')
  local current_path = ''

  for k, v in ipairs(pieces) do
    if File.ext(v) != nil then
      break
    end

    current_path = current_path..v..'/'

    if !file.Exists(current_path, 'DATA') then
      file.CreateDir(current_path)
    end
  end

  return file.old_write(file_name, contents)
end

do
  local action_storage = Flux.action_storage or {}
  Flux.action_storage = action_storage

  --- Registers an action that can be assigned to a player. The value is stored as given;
  -- note that Player#do_action only runs it if it is a table with a callback function
  -- field, which is then called with the player and the action ID.
  -- @param id [String identifier of the action]
  -- @param callback=nil [Map/Function handler of the action, see above]
  function Flux.register_action(id, callback)
    action_storage[id] = callback
  end

  --- Retrieves whatever was registered for the action with the specified identifier.
  -- @param id [String identifier of the action]
  -- @return [Map/Function the registered value, or nil if there is none]
  function Flux.get_action(id)
    return action_storage[id]
  end

  --- Returns the table storing all of the actions, keyed by identifier. This is the storage
  -- table itself, not a copy.
  -- @return [Map]
  function Flux.get_all_actions()
    return action_storage
  end

  Flux.register_action('spawning')
  Flux.register_action('idle')
end

--- Gets the folder of the currently loaded schema.
-- @return [String the schema folder; the client falls back to 'flux' if it is not known yet]
function Flux.get_schema_folder()
  if SERVER then
    return Flux.schema
  else
    return Flux.shared.schema_folder or 'flux'
  end
end

--- Gets the name of the currently loaded schema.
-- @return [String the schema name, or 'Unknown' if it cannot be determined]
function Flux.get_schema_name()
  return SCHEMA and SCHEMA:get_name() or Flux.schema or 'Unknown'
end

--- Includes the files of the currently loaded schema. On the client, shortly afterwards
-- notifies the server and runs the FluxClientSchemaLoaded hook.
function Flux.include_schema()
  if SERVER then
    return Plugin.include_schema()
  else
    Plugin.include_schema()

    -- Wait just a tiny bit for stuff to catch up
    timer.Simple(0.2, function()
      Cable.send('fl_client_included_schema', true)
      hook.run('FluxClientSchemaLoaded')
    end)
  end
end

--- Includes all of the plugins inside the folder, files first, then folders. Does not
-- handle plugins nested inside of other plugins.
-- @param folder [String folder relative to the Lua search paths (lua/, gamemodes/)]
function Flux.include_plugins(folder)
  return Plugin.include_plugins(folder)
end

--- Gets the table containing the information about the currently loaded schema. The server
-- reads it from the schema's gamemode .txt file once and caches it; the client uses the
-- copy shared by the server.
-- @return [Map schema info with the name, author, description, version and folder fields]
function Flux.get_schema_info()
  if SERVER then
    if Flux.schema_info then return Flux.schema_info end

    local schema_folder = string.lower(Flux.get_schema_folder())
    local schema_data = util.KeyValuesToTable(
      File.read('gamemodes/'..schema_folder..'/'..schema_folder..'.txt')
    ) or {}

    if schema_data['Gamemode'] then
      schema_data = schema_data['Gamemode']
    end

    Flux.schema_info = {}
      Flux.schema_info['name']        = schema_data['title'] or 'Undefined'
      Flux.schema_info['author']      = schema_data['author'] or 'Undefined'
      Flux.schema_info['description'] = schema_data['description'] or 'Undefined'
      Flux.schema_info['version']     = schema_data['version'] or 'Undefined'
      Flux.schema_info['folder']      = string.gsub(schema_folder, '/schema', '')
    return Flux.schema_info
  else
    return Flux.shared.schema_info
  end
end

do
  local global_offset = { x = 0, y = 0 }

  --- Sets the offset returned by Flux.global_ui_offset.
  -- @warning [Internal]
  -- @param x [Number]
  -- @param y [Number]
  function Flux.__set_global_offset__(x, y)
    global_offset = { x = x, y = y }
  end

  --- Returns the global UI offset, which follows the local player's view movement. HUD
  -- elements add it to their position to appear to lag behind the camera.
  -- @return [Number x offset, Number y offset]
  function Flux.global_ui_offset()
    return global_offset.x, global_offset.y
  end
end

if SERVER then
  Flux.shared.schema_info = Flux.get_schema_info()
end
