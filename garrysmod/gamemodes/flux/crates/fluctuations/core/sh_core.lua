AddCSLuaFile()

if !string.parse_parent then
  include 'flux/cratesflow/lib/sh_aliases.lua'
  include 'flux/crates/flow/lib/sh_string.lua'
end

--
-- Function: Flux.print (any message)
-- Description: Prints a message to the console.
-- Argument: any message - Any variable to be printed. If it's table, PrintTable will automatically be used.
--
-- Returns: nil
--
function Flux.print(message)
  if !istable(message) then
    print(message)
  else
    PrintTable(message)
  end
end

function Flux.dev_print(message)
  if Flux.development or Settings.debug_output_in_production then
    Msg('Debug: ')
    MsgC(Color(200, 200, 200), message)
    Msg('\n')
  end
end

--
-- Function: file.Write (string file_name, string fileContents)
-- Description: Writes a file to the data/ folder. This detour adds the ability for it to create all of the folders leading to the file path automatically.
-- Argument: string file_name - The name of the file to write. See http://wiki.garrysmod.com/page/file/Write for futher documentation.
-- Argument: string fileContents - Contents of the file as a NULL-terminated string.
--
-- Returns: nil
--
file.old_write = file.old_write or file.Write

function file.Write(file_name, contents)
  local pieces = file_name:split('/')
  local current_path = ''

  for k, v in ipairs(pieces) do
    if string.GetExtensionFromFilename(v) != nil then
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

  --
  -- Function: Flux.register_action (string id, function callback)
  -- Description: Registers an action that can be assigned to a player.
  -- Argument: string id - Identifier of the action.
  -- Argument: function callback - Function to call when the action is executed.
  --
  -- Returns: nil
  --
  function Flux.register_action(id, callback)
    action_storage[id] = callback
  end

  --
  -- Function: Flux.get_action (string id)
  -- Description: Retreives the action callback with the specified identifier.
  -- Argument: string id - ID of the action to get the callback of.
  --
  -- Returns: function - The callback.
  --
  function Flux.get_action(id)
    return action_storage[id]
  end

  --
  -- Function: Flux.get_all_actions ()
  -- Description: Can be used to directly access the table storing all of the actions.
  --
  -- Returns: table - The action_storage table.
  --
  function Flux.get_all_actions()
    return action_storage
  end

  Flux.register_action('spawning')
  Flux.register_action('idle')
end

--
-- Function: Flux.get_schema_folder ()
-- Description: Gets the folder of the currently loaded schema.
--
-- Returns: string - The folder of the currently loaded schema.
--
function Flux.get_schema_folder()
  if SERVER then
    return Flux.schema
  else
    return Flux.shared.schema_folder or 'flux'
  end
end

-- A function to get schema's name.
function Flux.get_schema_name()
  return Schema and Schema:get_name() or Flux.schema or 'Unknown'
end

--
-- Function: Flux.serialize (table toSerialize)
-- Description: Converts a table into the string format.
-- Argument: table toSerialize - Table to convert.
--
-- Returns: string - pON-encoded table. If pON fails then JSON is returned.
--
function Flux.serialize(tab)
  if istable(tab) then
    local success, value = pcall(pon.encode, tab)

    if !success then
      success, value = pcall(util.TableToJSON, tab)

      if !success then
        ErrorNoHalt('Failed to serialize a table!\n')
        ErrorNoHalt(value..'\n')

        return ''
      end
    end

    return value
  else
    print('You must serialize a table, not '..type(tab)..'!')
    return ''
  end
end

--
-- Function: Flux.deserialize (string toDeserialize)
-- Description: Converts a string back into table. Uses pON at first, if it fails it falls back to JSON.
-- Argument: string toDeserialize - String to convert.
--
-- Returns: table - Decoded string.
--
function Flux.deserialize(data)
  if isstring(data) then
    local success, value = pcall(pon.decode, data)

    if !success then
      success, value = pcall(util.JSONToTable, data)

      if !success then
        ErrorNoHalt('Failed to deserialize a string!\n')
        ErrorNoHalt(value..'\n')

        return {}
      end
    end

    return value
  else
    print('You must deserialize a string, not '..type(data)..'!')
    return {}
  end
end

--
-- Function: Flux.include_schema ()
-- Description: Includes the currently loaded schema's files. Performs deferred load on client.
--
-- Returns: nil
--
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

--
-- Function: Flux.include_plugins (string folder)
-- Description: Includes all of the plugins inside the folder. Includes files first, then folders. Does not handle plugin-inside-of-plugin scenarios.
-- Argument: string folder - Folder relative to Lua's PATH (lua/, gamemodes/).
--
-- Returns: nil
--
function Flux.include_plugins(folder)
  return Plugin.include_plugins(folder)
end

--
-- Function: Flux.get_schema_info ()
-- Description: Gets the table containing all of the information about the currently loaded schema.
--
-- Returns: table - The schema info table.
--
function Flux.get_schema_info()
  if SERVER then
    if Flux.schema_info then return Flux.schema_info end

    local schema_folder = string.lower(Flux.get_schema_folder())
    local schema_data = util.KeyValuesToTable(
      fileio.Read('gamemodes/'..schema_folder..'/'..schema_folder..'.txt')
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

if SERVER then
  Flux.shared.schema_info = Flux.get_schema_info()
end
