--- Entry point of the Client Settings package, run on both realms. Every player has options
-- of their own that they change in the Settings tab of the tab menu, as opposed to the
-- configs of the `Config` library, which belong to the server.
--
-- A setting is registered with `ClientSettings:register_setting`, at file level by the code
-- that owns it, or from the `RegisterClientSettings` hook when it depends on something that
-- is only known once every plugin and the schema have loaded. It has a type ('boolean',
-- 'number', 'choice' or 'string' out of the box, more can be added with
-- `ClientSettings:register_type`), a default value, a category, a name and a description, and
-- optionally a function that decides whether the player sees it in the menu and a function
-- that is called when its value changes. The package registers the language setting itself.
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
--
-- The package loads the registry, the values of the local player, the types, the language
-- setting and the player extension, then the settings menu, the hooks and the network
-- message handler. On the server it also registers the package's languages with `Pipeline`.
-- During a partial code reload (`LITE_REFRESH`) nothing is loaded again.
-- @module [ClientSettings]

if !LITE_REFRESH then
  require_relative 'lib/sh_client_settings'
  require_relative 'lib/cl_client_settings'
  require_relative 'lib/sh_types'
  require_relative 'lib/cl_language'
  require_relative_folder('lib/meta', true)

  if SERVER then
    Pipeline.include_folder('language', PACKAGE.__path__..'languages')
  end

  require_relative_folder('views', true)
  require_relative_folder('hooks', true)
  require_relative_folder('nethooks', true)
end
