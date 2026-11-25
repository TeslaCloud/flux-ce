--- Core of the Flux package, included as a dependency by its package specification.
-- Sets the environment constants (`IS_PRODUCTION`, `IS_DEVELOPMENT` and `IS_TEST`), loads the
-- `Pipeline`, `Plugin` and `Config` libraries, provides the version of Flux, debug output and
-- the loaded schema (its folder, name, information and inclusion) and reloads the
-- dependencies of the package on a code refresh. `boot.lua` includes the schema once every
-- package is in.
-- On the server it also reads `settings.yml` and `database.yml`, each found with
-- `Flux.find_config`, into the `Settings` and `DatabaseSettings` globals and shares the schema
-- information with clients.

AddCSLuaFile()

if !Flux then
  require_relative 'flux_struct'
end

IS_PRODUCTION    = ENV['FLUX_ENV'] == 'production'
IS_DEVELOPMENT   = !IS_PRODUCTION
IS_TEST          = ENV['FLUX_ENV'] == 'test'

Flux.development = !IS_PRODUCTION

local debug_color = Color(200, 200, 200)

--- Returns the version of Flux, as declared in the package specification of the Flux package.
-- @return [String]
function Flux.get_version()
  return Flux.__package__.version
end

--- Prints a debug message to the console, but only in development or when the
-- debug_output_in_production setting is enabled.
-- @param message [String]
function Flux.dev_print(message)
  if Flux.development or Settings.debug_output_in_production then
    Msg('Debug: ')
    MsgC(debug_color, message)
    Msg('\n')
  end
end

if !Pipeline or !Plugin or !Config then
  require_relative 'pipeline'
  require_relative 'plugin'
  require_relative 'config'
end

--- Gets the folder of the currently loaded schema.
-- @return [String the schema folder; the client falls back to the active gamemode if it is
--   not known yet]
function Flux.get_schema_folder()
  if SERVER then
    return Flux.schema
  else
    return Flux.shared.schema_folder or engine.ActiveGamemode()
  end
end

--- Gets the name of the currently loaded schema.
-- @return [String the schema name, or 'Unknown' if it cannot be determined]
function Flux.get_schema_name()
  return SCHEMA and SCHEMA:get_name() or Flux.schema or 'Unknown'
end

--- Includes the files of the currently loaded schema. On the client, shortly afterward
-- notifies the server and runs the ClientSchemaLoaded hook.
function Flux.include_schema()
  if SERVER then
    return Plugin.include_schema()
  else
    Plugin.include_schema()

    timer.Simple(0.2, function()
      Cable.send('fl_client_included_schema', true)
      --- Called on the client shortly after the schema files have been included, right after
      -- the server has been told about it (which runs `PlayerSchemaLoaded` there). The
      -- gamemode's handler creates the fonts.
      hook.Run('ClientSchemaLoaded')
    end)
  end
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

    Flux.schema_info = {
      name        = schema_data['title'] or 'Undefined',
      author      = schema_data['author'] or 'Undefined',
      description = schema_data['description'] or 'Undefined',
      version     = schema_data['version'] or 'Undefined',
      folder      = schema_folder
    }

    return Flux.schema_info
  else
    return Flux.shared.schema_info
  end
end

if PACKAGE then
  --- Called by the Package manager once the Flux package has been included.
  -- On a code refresh it reloads the dependencies of the package in the order they are listed
  -- (on a lite refresh only the flow and active_ui packages, whose shared files are needed
  -- either way). Only the server makes lite refreshes, see `LITE_REFRESH` in `boot.lua`. Does
  -- nothing on the first boot.
  function PACKAGE:__installed__()
    if !Flux.initialized then return end

    if !LITE_REFRESH then
      for _, dep_name in ipairs(self.metadata.deps) do
        Package:reload(dep_name)
      end
    else
      Package:reload 'flow'
      Package:reload 'active_ui'
    end
  end
end

if !SERVER then return end

--- Finds a configuration file. The server's own config lives in the `config` folder of the
-- schema's gamemode and replaces the file that ships with Flux, file by file: the first that
-- exists of `<name>.local.<ext>` and `<name>.<ext>` there is used, else the file of the same
-- name in the `config` folder of the Flux package.
-- ```
-- Flux.find_config('settings.yml') -- 'gamemodes/hl2rp/config/settings.local.yml'
-- ```
-- @realm [server]
-- @param file_name [String name of the file with its extension, such as 'database.yml']
-- @return [String path of the file relative to the game folder]
-- @see [find_config_file]
function Flux.find_config(file_name)
  return find_config_file(file_name, 'GAME')
end

--- Reads a YAML file that holds a map, such as `settings.yml`, a `plugin.yml` or the .yml file of
-- the schema. A file that is empty or holds nothing but comments reads as an empty map.
-- ```
-- Flux.read_yaml(Flux.find_config('settings.yml'))
-- ```
-- @realm [server]
-- @param path [String path of the file]
-- @param path_id='GAME' [String search path the path is relative to, such as 'GAME' or 'LUA']
-- @return [Map the parsed file, or nil if the file does not exist; throws an error naming the
--   file if it is not valid YAML or does not hold a map]
function Flux.read_yaml(path, path_id)
  local contents = file.Read(path, path_id or 'GAME')

  if !contents then return end

  if contents:gsub('#[^\n]*', ''):match('^%s*$') then
    return {}
  end

  local success, result = pcall(YAML.eval, contents)

  if !success then
    error('Invalid YAML in '..path..': '..tostring(result), 0)
  elseif !istable(result) then
    error('Invalid YAML in '..path..': the file has to hold a map of keys to values', 0)
  end

  return result
end

Settings          = Settings or Flux.read_yaml(Flux.find_config('settings.yml'))
DatabaseSettings  = Flux.read_yaml(Flux.find_config('database.yml'))

AddCSLuaFile('_flux/environment.lua')

Flux.shared.schema_info = Flux.get_schema_info()
