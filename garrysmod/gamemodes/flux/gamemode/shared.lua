-- Define basic GM info fields.
GM.Name          = 'Flux'
GM.Author        = 'TeslaCloud Studios'
GM.Website       = 'https://teslacloud.net/'
GM.Email         = 'support@teslacloud.net'

-- Define Flux-Specific fields.
GM.version       = '0.4.1-alpha'
GM.version_num   = '0.4.1'
GM.date          = '9/30/2018'
GM.build         = '20180930'
GM.description   = 'A free roleplay gamemode framework.'
GM.code_name     = 'Apple Cider'

-- It would be very nice of you to leave below values as they are if you're using official schemas.
-- While we can do nothing to stop you from changing them, we'll very much appreciate it if you don't.
GM.name_override = false -- Set to any string to override schema's browser name. This overrides the prefix too.

-- Environment stuff
FLUX_ENV         = include 'flux/config/environment.lua' or 'development'
IS_DEVELOPMENT   = FLUX_ENV == 'development'
IS_STAGING       = FLUX_ENV == 'staging'
IS_PRODUCTION    = FLUX_ENV == 'production'
LITE_REFRESH     = fl.initialized and Settings.lite_refresh or false

fl.development   = !IS_PRODUCTION

-- Aliases for serverside and clientside constants.
sv               = SERVER
cl               = CLIENT

-- Fix for the name conflicts.
_player, _team, _file, _table, _sound = player, team, file, table, sound

AddCSLuaFile     'flux/config/environment.lua'

if engine.ActiveGamemode() != 'flux' then
  fl.schema = engine.ActiveGamemode()
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
  fl.shared = fl.shared or {
    schema_folder = fl.schema,
    plugin_info = {},
    unloaded_plugins = {}
  }

  print('Flux environment: '..FLUX_ENV)

  include 'core/sh_core.lua'
  util.include 'core/sh_enums.lua'

  util.include_folder('lib/util', true)

  if CLIENT then
    local files, folders = file.Find('flux/client/*.lua', 'LUA')

    for k, v in ipairs(files) do
      include('flux/client/'..v)
    end

    include 'lib/sh_lang.lua'
  end

  util.include 'core/cl_core.lua'
  util.include 'core/sv_core.lua'

  -- This way we put things we want loaded BEFORE anything else in here, like plugin, config, etc.
  util.include_folder('lib/required', true)

  -- Include ActiveRecord for database management
  util.include 'lib/activerecord/ar_shared.lua'

  -- So that we don't get duplicates on refresh.
  plugin.clear_cache()

  util.include_folder('config', true)
  util.include_folder('lib', true)
  util.include_folder('lib/classes', true)
  util.include_folder('lib/meta', true)
  if SERVER then
    pipeline.include_folder('language', 'flux/gamemode/languages')
    pipeline.include_folder('migrations', 'flux/gamemode/migrations')
    pipeline.include_folder('html', 'flux/gamemode/views/html')
    pipeline.include_folder('html', 'flux/gamemode/views/assets/stylesheets')
    pipeline.include_folder('html', 'flux/gamemode/views/assets/javascripts')
  end
  util.include_folder('models', true)
  util.include_folder('controllers', true)
  util.include_folder('views/base', true)
  util.include_folder('views', true)

  if theme or SERVER then
    pipeline.register('theme', function(id, file_name, pipe)
      if CLIENT then
        THEME = Theme.new(id)

        util.include(file_name)

        THEME:register() THEME = nil
      else
        util.include(file_name)
      end
    end)

    -- Theme factory is needed for any other themes that may be in the themes folder.
    pipeline.include('theme', 'themes/cl_theme_factory.lua')
    pipeline.include_folder('theme', 'flux/gamemode/themes')
  end

  pipeline.include_folder('tool', 'flux/gamemode/tools')
end

util.include_folder('hooks', true)

if !LITE_REFRESH then
  hook.run('PreLoadPlugins')

  fl.include_plugins('flux/plugins')
end

hook.run('OnPluginsLoaded')

fl.include_schema()
