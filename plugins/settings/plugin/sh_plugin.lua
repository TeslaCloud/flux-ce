--- Settings gives every player options of their own that they change in the Settings tab of
-- the tab menu, as opposed to the configs of the `Config` library, which belong to the server.
-- A setting is registered with `ClientSettings:register_setting` from the
-- `RegisterClientSettings` hook. It has a type ('boolean', 'number', 'choice' or 'string'
-- out of the box, more can be added with `ClientSettings:register_type`), a default value,
-- a category, a name and a description, and optionally a function that decides whether the
-- player sees it in the menu and a function that is called when its value changes.
--
-- The values live on the client. They are kept in the 'settings' file of the client data
-- store (`Data.save`), so they follow the player from session to session and from server to
-- server. `ClientSettings:get` reads one and returns the default of the setting for as long
-- as the player has not changed it; `ClientSettings:set` and `ClientSettings:reset` change
-- one and run the `ClientSettingChanged` hook.
--
-- A setting that is registered as `networked` is also sent to the server: all of them when
-- the player joins, and one whenever it changes. The server checks what it receives against
-- the definition of the setting, runs `PlayerSettingChanged` and answers
-- `Player:get_setting`. For that to work a networked setting has to be registered on both
-- the server and the client, which is the case when it is registered from shared code.
-- @module [ClientSettings]

PLUGIN:set_global('ClientSettings')

require_relative 'cl_plugin'
require_relative 'cl_hooks'
require_relative 'sv_nethooks'

--- Runs the RegisterClientSettings hook so that plugins and the schema can register their
-- settings. On the client it then sends the networked settings to the server again if they
-- have been sent before, which is the case after a code refresh.
function ClientSettings:OnSchemaLoaded()
  --- Lets plugins and the schema register their settings with
  -- `ClientSettings:register_setting`. Called on the server and the client once all plugins
  -- and the schema have been loaded, and again on every code refresh. Register a setting on
  -- both realms if it is networked; a setting that is not can be registered on the client
  -- only. A type added with `ClientSettings:register_type` has to be registered before the
  -- settings that use it. Do not return anything from the handler, or the plugins after it
  -- are not asked.
  hook.Run('RegisterClientSettings')

  if CLIENT and self.ready then
    self:sync_all()
  end
end
