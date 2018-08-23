-- Define basic GM info fields.
GM.name         = "Flux"
GM.Author       = "TeslaCloud Studios"
GM.Website      = "http://teslacloud.net/"
GM.Email        = "support@teslacloud.net"

-- Define Flux-Specific fields.
GM.version      = "0.2.9-indev"
GM.version_num  = "0.2.9"
GM.date         = "11/4/2017"
GM.build        = "1592"
GM.description  = "A free roleplay gamemode framework."

-- It would be very nice of you to leave below values as they are if you're using official schemas.
-- While we can do nothing to stop you from changing them, we'll very much appreciate it if you don't.
GM.nameOverride = false -- Set to any string to override schema's browser name. This overrides the prefix too.

-- Environment stuff
FLUX_ENV        = Settings.environment or 'development'
IS_DEVELOPMENT  = FLUX_ENV == 'development'
IS_STAGING      = FLUX_ENV == 'staging'
IS_PRODUCTION   = FLUX_ENV == 'production'

fl.development  = !IS_PRODUCTION

print('Flux environment: '..FLUX_ENV)

-- Fix for the name conflicts.
_player, _team, _file, _table, _sound = player, team, file, table, sound

-- do - end blocks help us manage the scope of the variables,
-- as well as create a separate Lua Closure for that bit of code.
-- Locals within the same closure as the function are generally
-- accessed faster than the ones in the file scope closure.
-- In this particular case it's not necessary, because we
-- already have if - then - end structure, but I thought leaving
-- an example somewhere in the init code would be nice.
do
  if (engine.ActiveGamemode() != "flux") then
    fl.schema = engine.ActiveGamemode()
  else
    ErrorNoHalt(txt[[
      ============================================
      +gamemode is set to 'flux'!
      Set it to your schema's folder name instead!
      ============================================
    ]])

    return
  end

  -- Shared table contains the info that will be networked
  -- to clients automatically when they load.
  fl.shared = fl.shared or {
    schema_folder = fl.schema,
    pluginInfo = {},
    unloadedPlugins = {}
  }
end

-- A function to get schema's name.
function fl.GetSchemaName()
  return (Schema and Schema:get_name()) or fl.schema or "Unknown"
end

-- Called when gamemode's server browser name needs to be retrieved.
function GM:GetGameDescription()
  local nameOverride = self.nameOverride

  return (isstring(nameOverride) and nameOverride) or "FL - "..fl.GetSchemaName()
end

include("core/sh_util.lua")

util.include("core/sh_enums.lua")
util.include("core/sh_core.lua")
util.include("core/cl_core.lua")
util.include("core/sv_core.lua")

-- This way we put things we want loaded BEFORE anything else in here, like plugin, config, etc.
util.include_folder("core/lib/required", true)

-- So that we don't get duplicates on refresh.
plugin.clear_cache()

util.include_folder("core/config", true)
util.include_folder("core/lib", true)
util.include_folder("core/lib/classes", true)
util.include_folder("core/lib/meta", true)
util.include_folder("languages", true)
util.include_folder("core/ui/controllers", true)
util.include_folder("core/ui/view/base", true)
util.include_folder("core/ui/view", true)

if (theme or SERVER) then
  pipeline.register("theme", function(id, fileName, pipe)
    if CLIENT then
      THEME = Theme(id)

      util.include(fileName)

      THEME:register() THEME = nil
    else
      util.include(fileName)
    end
  end)

  -- Theme factory is needed for any other themes that may be in the themes folder.
  pipeline.Include("theme", "core/themes/cl_theme_factory.lua")
  pipeline.include_folder("theme", "flux/gamemode/core/themes")
end

pipeline.include_folder("tool", "flux/gamemode/core/tools")
util.include_folder("hooks", true)

hook.Run("PreLoadPlugins")

fl.include_plugins("flux/plugins")

hook.Run("OnPluginsLoaded")

fl.include_schema()
