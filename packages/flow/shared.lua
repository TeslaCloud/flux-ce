--- Entry point of the Flux gamemode package, run on both realms.
-- Fills in the gamemode information (`GM.Name`, `GM.version`, `GM.code_name` and so on)
-- from the package metadata, then loads the core, the libraries, classes and metatable
-- extensions, the models and the tools, and finally the gamemode hooks. On the server it
-- also registers the package's languages and migrations with `Pipeline`. The user interface
-- lives in the Active UI package, which is loaded after this one. During a partial code
-- reload (`LITE_REFRESH`) only the hooks are loaded again.

local metadata = Flux.__package__

-- Define basic GM info fields.
GM.Name          = metadata.name
GM.Author        = metadata.author[1]
GM.Website       = metadata.website
GM.Email         = metadata.email

local version    = metadata.version

-- Define Flux-Specific fields.
GM.version       = version
GM.date          = metadata.date
GM.build         = string.gsub(metadata.date or '', '%-', '')
GM.description   = metadata.description
GM.code_name     = 'Root Beer'

print('Flux core version '..version..' ('..GM.code_name..')')

-- It would be very nice of you to leave the below values as they are if you're using official schemas.
-- While we can do nothing to stop you from changing them, we'll very much appreciate it if you don't.
GM.name_override = false -- Set to any string to override the schema's browser name. This overrides the prefix too.

AddCSLuaFile(FLUX_ENV_PATH)

--- Returns the version of the Flux core, as declared in its package metadata.
-- @return [String]
function Flux.get_version()
  return version
end

-- So that we don't get duplicates on refresh.
Plugin.clear_cache()

if !LITE_REFRESH then
  print('Environment: '..ENV['FLUX_ENV'])

  local package_path = PACKAGE.__path__

  require_relative 'core/sh_core'
  require_relative 'core/sh_enums'

  if CLIENT then
    include 'lib/sh_lang.lua'
  end

  require_relative 'core/cl_core'
  require_relative 'core/sv_core'

  -- Read configs.
  Config.read(Settings.configs)

  require_relative_folder('lib', true)
  require_relative_folder('lib/classes', true)
  require_relative_folder('lib/meta', true)

  if SERVER then
    Pipeline.include_folder('language', package_path..'languages')
    Pipeline.include_folder('migrations', package_path..'migrations')
  end

  require_relative_folder('models', true)

  Pipeline.include_folder('tool', package_path..'tools')
else
  print 'Performing partial code reload...'
end

require_relative_folder('hooks', true)
