--- Shared hooks of the Client Settings package, registered as `ClientSettings`: collecting the
-- settings that depend on every plugin and the schema once they have loaded.

local hooks = {}

--- Runs the RegisterClientSettings hook so that plugins and the schema can register the
-- settings that depend on what has loaded. On the client it then sends the networked
-- settings to the server again if they have been sent before, which is the case after a code
-- refresh.
function hooks:SchemaLoaded()
  --- Lets plugins and the schema register settings with `ClientSettings:register_setting`
  -- once all plugins and the schema have been loaded, for settings that depend on what they
  -- register; any other setting may be registered here or at file level. Called on the server
  -- and the client, and again on every code refresh. Register a setting on both realms if it is
  -- networked; a setting that is not can be registered on the client only. A type added with
  -- `ClientSettings:register_type` has to be registered before the settings that use it. Do
  -- not return anything from the handler, or the plugins after it are not asked.
  hook.Run('RegisterClientSettings')

  if CLIENT and ClientSettings.ready then
    ClientSettings:sync_all()
  end
end

Plugin.add_hooks('ClientSettings', hooks)
