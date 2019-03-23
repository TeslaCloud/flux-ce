local metadata = Flux.__crate__

-- Define basic GM info fields.
GM.Name          = metadata.name
GM.Author        = metadata.author[1]
GM.Website       = metadata.email
GM.Email         = metadata.website

local version    = metadata.version

-- Define Flux-Specific fields.
GM.version       = version
GM.date          = metadata.date
GM.build         = string.gsub(metadata.date or '', '%-', '')
GM.description   = metadata.description
GM.code_name     = 'Sweet Mead'

print('Flux core version '..version..' ('..GM.code_name..')')

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
  print('Environment: '..FLUX_ENV)

  require_relative 'core/sh_core'
  require_relative 'core/sh_enums'

  if CLIENT then
    local files, folders = file.Find('_flux/client/*.lua', 'LUA')

    for k, v in ipairs(files) do
      include('_flux/client/'..v)
    end

    include 'lib/sh_lang.lua'
  end

  require_relative 'core/cl_core'
  require_relative 'core/sv_core'

  -- Read configs.
  Config.read(Settings.configs)

  -- So that we don't get duplicates on refresh.
  Plugin.clear_cache()

  require_relative_folder('lib', true)
  require_relative_folder('lib/classes', true)
  require_relative_folder('lib/meta', true)
  if SERVER then
    Pipeline.include_folder('language', 'flux/crates/fluctuations/languages')
    Pipeline.include_folder('migrations', 'flux/crates/fluctuations/migrations')
    Pipeline.include_folder('html', 'flux/crates/fluctuations/views/html')
    Pipeline.include_folder('html', 'flux/crates/fluctuations/views/assets/stylesheets')
    Pipeline.include_folder('html', 'flux/crates/fluctuations/views/assets/javascripts')
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
    Pipeline.include_folder('Theme', 'flux/crates/fluctuations/themes')
  end

  Pipeline.include_folder('tool', 'flux/crates/fluctuations/tools')
end

require_relative_folder('hooks', true)

Flux.include_schema()
