--- Client-side hooks of the Client Settings package, registered as `ClientSettings`: the
-- Settings entry of the tab menu, the first synchronization of the networked settings with
-- the server, saving on shutdown, keeping the open settings menu up to date and keeping the
-- language setting in step with the language of the client.

local hooks = {}

--- Adds the Settings entry to the tab menu.
-- @param menu [Panel the tab menu]
function hooks:AddTabMenuItems(menu)
  menu:add_menu_item('settings', {
    title = t'ui.tab_menu.settings',
    panel = 'fl_settings',
    icon = 'fa-cog',
    priority = 60
  })
end

--- Sends the networked settings to the server as soon as the client is able to, so that the
-- server knows them before it runs PlayerInitialized for the local player.
function hooks:InitPostEntity()
  ClientSettings:sync_all()
end

--- Writes the settings to the data store when the game shuts down while a change is still
-- waiting to be saved.
function hooks:ShutDown()
  if timer.Exists('fl_settings_save') then
    ClientSettings:save()
  end
end

--- Updates the settings menu, if it is open, when the value of a setting has changed.
-- @param id [String setting id]
-- @param _value [Any new value of the setting]
-- @param _old_value [Any previous value of the setting]
function hooks:ClientSettingChanged(id, _value, _old_value)
  local menu = ClientSettings.menu

  if IsValid(menu) then
    menu:update_setting(id)
  end
end

--- Keeps the language setting in step when the language of the client changes for another
-- reason than the setting itself, such as the fl_language console variable.
-- @param _new_lang [String new language code]
-- @param _old_lang [String previous language code]
function hooks:LanguageChanged(_new_lang, _old_lang)
  ClientSettings:follow_language()
end

Plugin.add_hooks('ClientSettings', hooks)
