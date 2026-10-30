--- Core of the Flux package, included as a dependency by its package specification.
-- Sets the environment constants (`IS_PRODUCTION`, `IS_DEVELOPMENT` and `IS_TEST`), loads the
-- `Pipeline`, `Plugin` and `Config` libraries, provides the version of Flux, debug output and
-- the loaded schema (its folder, name, information and inclusion) and defines what happens
-- once the package and all of its dependencies have been included: the schema is loaded and
-- the FluxPackageLoaded hook runs.
-- On the server it also reads `settings.yml`, `config.yml` and `database.yml` from the
-- gamemode's `config` folder into the `Settings` and `DatabaseSettings` globals and shares the
-- schema information with clients.

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
      folder      = string.gsub(schema_folder, '/schema', '')
    }

    return Flux.schema_info
  else
    return Flux.shared.schema_info
  end
end

if PACKAGE then
  --- Called by the Package manager once the Flux package has been included.
  -- Reloads the dependencies when this is a code refresh (on a lite refresh only the flow and
  -- active_ui packages, whose shared files are needed either way), includes the schema and
  -- runs the FluxPackageLoaded hook.
  function PACKAGE:__installed__()
    if Flux.initialized then
      if !LITE_REFRESH then
        for _, dep_name in pairs(self.metadata.deps) do
          Package:reload(dep_name)
        end
      else
        Package:reload 'flow'
        Package:reload 'active_ui'
      end
    end

    Flux.include_schema()

    --- Called once the Flux package, all of its dependencies and the schema with its plugins
    -- have been included.
    -- Runs on both the server and the client, on boot and again every time a code refresh
    -- reloads the package.
    hook.Call('FluxPackageLoaded', GM or GAMEMODE)
    Flux.initialized = true
  end
end

if !SERVER then return end

Settings          = Settings or YAML.read('gamemodes/flux/config/settings.yml')
Settings.configs  = Settings.configs or YAML.read('gamemodes/flux/config/config.yml')
DatabaseSettings  = YAML.read('gamemodes/flux/config/database.yml')

LITE_REFRESH = Flux.initialized and Settings.lite_refresh or false

AddCSLuaFile('_flux/environment.lua')

Flux.shared.schema_info = Flux.get_schema_info()
