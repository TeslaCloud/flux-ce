-- Define basic GM info fields.
GM.Name          = 'Flux'
GM.Author        = 'TeslaCloud Studios'
GM.Website       = 'https://teslacloud.net/'
GM.Email         = 'support@teslacloud.net'

local version    = '0.6.0-alpha'

-- Define Flux-Specific fields.
GM.version       = version
GM.version_num   = '0.6.0'
GM.date          = '3/13/2019'
GM.build         = '20190313'
GM.description   = 'A free roleplay gamemode framework.'
GM.code_name     = 'Cherry Soda'

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

if engine.ActiveGamemode() != 'flux' then
  Flux.schema = engine.ActiveGamemode()
else
  ErrorNoHalt(txt[[
    ============================================
             +gamemode is set to 'flux'
    Set it to your schema's folder name instead!
    ============================================
  ]])

  return
end

if !LITE_REFRESH then
  -- Shared table contains the info that will be networked
  -- to clients automatically when they load.
  Flux.shared = Flux.shared or {
    schema_folder = Flux.schema,
    plugin_info = {},
    unloaded_plugins = {}
  }

  print('Flux environment: '..FLUX_ENV)

  include 'core/sh_core.lua'
  util.include 'core/sh_enums.lua'

  if CLIENT then
    local files, folders = file.Find('_flux/client/*.lua', 'LUA')

    for k, v in ipairs(files) do
      include('_flux/client/'..v)
    end

    include 'lib/sh_lang.lua'
  end

  -- Include the Crate (Flux libraries) class
  util.include 'lib/required/sh_crate.lua'

  Crate:include 'flow'

  util.include 'core/cl_core.lua'
  util.include 'core/sv_core.lua'

  -- This way we put things we want loaded BEFORE anything else in here, like plugin, config, etc.
  util.include_folder('lib/required', true)

  -- Include ActiveRecord for database management.
  Crate:include 'active_record'

  -- And ActiveNetwork for easy variable networking.
  Crate:include 'active_network'

  -- So that we don't get duplicates on refresh.
  Plugin.clear_cache()

  util.include_folder('lib', true)
  util.include_folder('lib/classes', true)
  util.include_folder('lib/meta', true)
  if SERVER then
    Crate:include 'packager'

    Pipeline.include_folder('language', 'flux/gamemode/languages')
    Pipeline.include_folder('migrations', 'flux/gamemode/migrations')
    Pipeline.include_folder('html', 'flux/gamemode/views/html')
    Pipeline.include_folder('html', 'flux/gamemode/views/assets/stylesheets')
    Pipeline.include_folder('html', 'flux/gamemode/views/assets/javascripts')
  end
  util.include_folder('models', true)
  util.include_folder('controllers', true)
  util.include_folder('views/base', true)
  util.include_folder('views', true)

  if Theme or SERVER then
    Pipeline.register('Theme', function(id, file_name, pipe)
      if CLIENT then
        THEME = ThemeBase.new(id)

        util.include(file_name)

        THEME:register() THEME = nil
      else
        util.include(file_name)
      end
    end)

    -- Theme factory is needed for any other themes that may be in the themes folder.
    Pipeline.include('Theme', 'themes/cl_theme_factory.lua')
    Pipeline.include_folder('Theme', 'flux/gamemode/themes')
  end

  Pipeline.include_folder('tool', 'flux/gamemode/tools')
end

util.include_folder('hooks', true)

Flux.include_schema()
