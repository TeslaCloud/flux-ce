-- Define basic GM info fields.
GM.Name          = 'Flux'
GM.Author        = 'TeslaCloud Studios'
GM.Website       = 'https://teslacloud.net/'
GM.Email         = 'support@teslacloud.net'

local version    = '0.6.3-alpha'

-- Define Flux-Specific fields.
GM.version       = version
GM.version_num   = Flux.
GM.date          = '3/20/2019'
GM.build         = '20190322'
GM.description   = 'A free roleplay gamemode framework.'
GM.code_name     = 'Cherry Soda'

print('Flux version '..GM.version..' ('..GM.code_name..')')

-- It would be very nice of you to leave below values as they are if you're using official schemas.
-- While we can do nothing to stop you from changing them, we'll very much appreciate it if you don't.
GM.name_override = false -- Set to any string to override schema's browser name. This overrides the prefix too.

-- Environment stuff
FLUX_ENV_PATH    = file.Exists('flux/config/environment.local.lua', 'LUA') and 'flux/config/environment.local.lua' or 'flux/config/environment.lua'
FLUX_ENV         = include(FLUX_ENV_PATH) or 'development'
IS_DEVELOPMENT   = FLUX_ENV == 'development'
IS_STAGING       = FLUX_ENV == 'staging'
IS_PRODUCTION    = FLUX_ENV == 'production'
LITE_REFRESH     = Flux.initialized and Settings.lite_refresh or false

Flux.development   = !IS_PRODUCTION

-- Fix for the name conflicts.
_player, _team, _file, _table, _sound = player, team, file, table, sound

AddCSLuaFile(FLUX_ENV_PATH)

function Flux.get_version()
  return version
end

if !LITE_REFRESH then
  -- Shared table contains the info that will be networked
  -- to clients automatically when they load.
  Flux.shared = Flux.shared or {
    schema_folder = Flux.schema,
    plugin_info = {},
    unloaded_plugins = {},
    configs = {},
    deps_info = {}
  }

  print('Environment: '..FLUX_ENV)

  include 'core/sh_core.lua'
  require_relative 'core/sh_enums.lua'

  if CLIENT then
    local files, folders = file.Find('_flux/client/*.lua', 'LUA')

    for k, v in ipairs(files) do
      include('_flux/client/'..v)
    end

    include 'lib/sh_lang.lua'
  end

  -- Include the Crate (Flux libraries) class
  require_relative 'lib/required/sh_crate.lua'

  -- Fix colors on Linux!
  if SERVER and system.IsLinux() then
    Crate:include 'colorfix'
  end

  Crate:include 'flow'

  require_relative 'core/cl_core.lua'
  require_relative 'core/sv_core.lua'

  -- This way we put things we want loaded BEFORE anything else in here, like plugin, config, etc.
  require_relative_folder('lib/required', true)

  -- Read configs.
  Config.read(Settings.configs)

  -- Include ActiveRecord for database management.
  Crate:include 'active_record'

  -- And ActiveNetwork for easy variable networking.
  Crate:include 'active_network'

  -- So that we don't get duplicates on refresh.
  Plugin.clear_cache()

  require_relative_folder('lib', true)
  require_relative_folder('lib/classes', true)
  require_relative_folder('lib/meta', true)
  if SERVER then
    Crate:include 'packager'

    Pipeline.include_folder('language', 'flux/gamemode/languages')
    Pipeline.include_folder('migrations', 'flux/gamemode/migrations')
    Pipeline.include_folder('html', 'flux/gamemode/views/html')
    Pipeline.include_folder('html', 'flux/gamemode/views/assets/stylesheets')
    Pipeline.include_folder('html', 'flux/gamemode/views/assets/javascripts')
  end
  require_relative_folder('models', true)
  require_relative_folder('controllers', true)
  require_relative_folder('views/base', true)
  require_relative_folder('views', true)

  if Theme or SERVER then
    Pipeline.register('Theme', function(id, file_name, pipe)
      if CLIENT then
        THEME = ThemeBase.new(id)

        require_relative(file_name)

        THEME:register() THEME = nil
      else
        require_relative(file_name)
      end
    end)

    -- Theme factory is needed for any other themes that may be in the themes folder.
    Pipeline.include('Theme', 'themes/cl_theme_factory.lua')
    Pipeline.include_folder('Theme', 'flux/gamemode/themes')
  end

  Pipeline.include_folder('tool', 'flux/gamemode/tools')
end

require_relative_folder('hooks', true)

Flux.include_schema()
