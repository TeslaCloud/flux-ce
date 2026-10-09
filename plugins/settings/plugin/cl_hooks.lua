--- Client-side hooks of the Settings plugin: the Settings entry of the tab menu, the first
-- synchronization of the networked settings with the server, saving on shutdown and keeping
-- the open settings menu up to date.

--- Adds the Settings entry to the tab menu.
-- @param menu [Panel the tab menu]
function ClientSettings:AddTabMenuItems(menu)
  menu:add_menu_item('settings', {
    title = t'ui.tab_menu.settings',
    panel = 'fl_settings',
    icon = 'fa-cog',
    priority = 60
  })
end

--- Sends the networked settings to the server as soon as the client is able to, so that the
-- server knows them before it runs PlayerInitialized for the local player.
function ClientSettings:InitPostEntity()
  self:sync_all()
end

--- Writes the settings to the data store when the game shuts down while a change is still
-- waiting to be saved.
function ClientSettings:ShutDown()
  if timer.Exists('fl_settings_save') then
    self:save()
  end
end

--- Updates the settings menu, if it is open, when the value of a setting has changed.
-- @param id [String setting id]
-- @param value [Any new value of the setting]
-- @param old_value [Any previous value of the setting]
function ClientSettings:ClientSettingChanged(id, value, old_value)
  if IsValid(self.menu) then
    self.menu:update_setting(id)
  end
end
