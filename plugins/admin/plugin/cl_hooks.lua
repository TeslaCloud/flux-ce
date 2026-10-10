--- Client-side hooks of the admin plugin: the Admin entry of the tab menu and its pages,
-- keeping the config editor and the plugin manager up to date with the server, the vanish
-- indicator on the HUD, fullbright rendering and the voice permission check.

local IsValid = IsValid

--- Returns false for speakers that lack the 'voice' permission.
-- @param speaker [Player the player that started talking]
-- @return [Boolean false if the player lacks the permission, nothing otherwise]
function Bolt:PlayerStartVoice(speaker)
  if !speaker:can('voice') then
    return false
  end
end

--- Adds the Admin entry to the tab menu.
-- @param menu [Panel the tab menu]
function Bolt:AddTabMenuItems(menu)
  menu:add_menu_item('admin', {
    title = t'ui.tab_menu.admin',
    panel = 'fl_admin_panel',
    icon = 'fa-shield-alt',
    priority = 40
  })
end

--- Adds the pages of the admin plugin to the admin panel: player management, the staff
-- list, the ban list, the config editor and the plugin manager. Each one asks for the
-- permission that the server checks for what the page does; for the config editor that is
-- the permission named by `Config.permission`.
-- @param panel [Panel the admin panel]
-- @param sidebar [Panel the admin panel's sidebar]
function Bolt:AddAdminMenuItems(panel, sidebar)
  panel:add_panel('admin_player_management', t'ui.admin.player_management', 'manage_permissions')
  panel:add_panel('admin_staff_list', t'ui.admin.staff.title', 'manage_permissions')
  panel:add_panel('admin_ban_list', t'ui.admin.bans.title', 'unban')
  panel:add_panel('admin_config_editor', t'ui.admin.config_editor', Config.permission)
  panel:add_panel('admin_plugin_manager', t'ui.admin.plugins.title', 'manage_plugins')
end

--- Registers the constructors of the admin panel's pages with the loaded theme.
-- @param current_theme [ThemeBase]
function Bolt:OnThemeLoaded(current_theme)
  current_theme:add_panel('admin_player_management', function(id, parent, ...)
    return vgui.Create('fl_player_management', parent)
  end)

  current_theme:add_panel('admin_staff_list', function(id, parent, ...)
    return vgui.Create('fl_staff_list', parent)
  end)

  current_theme:add_panel('admin_ban_list', function(id, parent, ...)
    return vgui.Create('fl_ban_list', parent)
  end)

  current_theme:add_panel('admin_config_editor', function(id, parent, ...)
    return vgui.Create('fl_config_editor', parent)
  end)

  current_theme:add_panel('admin_plugin_manager', function(id, parent, ...)
    return vgui.Create('fl_plugin_manager', parent)
  end)
end

--- Updates the line of a config in the config editor, if it is open, when the value of
-- the config has arrived from the server.
-- @param key [String config key]
-- @param old_value [Any value the client had before]
-- @param new_value [Any value that has been received]
function Bolt:OnConfigReceived(key, old_value, new_value)
  if IsValid(self.config_editor) then
    self.config_editor:update_config(key)
  end
end

--- Updates the line of a config in the config editor, if it is open, when the server
-- reports that the config has got a pending value or no longer has one.
-- @param key [String config key]
-- @param is_pending [Boolean whether the config has a pending value now]
-- @param value [Any value the config takes on the next start of the server]
function Bolt:OnConfigPendingReceived(key, is_pending, value)
  if IsValid(self.config_editor) then
    self.config_editor:update_config(key)
  end
end

--- Rebuilds the list of the plugin manager, if it is open, when the server reports that a
-- plugin has been disabled or enabled.
-- @param id [String normalized ID of the plugin]
-- @param disabled [Boolean true if the plugin will be disabled after the restart]
function Bolt:OnPluginStateChanged(id, disabled)
  if IsValid(self.plugin_manager) then
    self.plugin_manager:rebuild()
  end
end

--- Draws the vanish indicator in the bottom right corner while the local player is hidden
-- from other players.
function Bolt:HUDPaint()
  local client = PLAYER

  if IsValid(client) and client:has_initialized() and client:Alive()
  and client:get_nv('transmission_prevented') then
    local text, font = t'ui.hud.vanish', Theme.get_font('text_normal')
    local w, h = util.text_size(text, font)
    local x, y = ScrW() - w - 16, ScrH() - h - 16
    FontAwesome:draw('fa-eye-slash', x - h - math.scale(12), y, h)
    draw.SimpleText(text, font, x, y, color_white)
  end
end

--- Switches to fullbright lighting when the local player's 'should_fullbright' net var is set.
function Bolt:PostRender()
  local client = PLAYER

  if IsValid(client) and client:get_nv('should_fullbright') then
    render.SetLightingMode(1)
    client.fullbright_enabled = true
  end
end

--- Restores normal lighting before the HUD is drawn if fullbright was switched on.
function Bolt:PreDrawHUD()
  local client = PLAYER

  if IsValid(client) and client.fullbright_enabled then
    render.SetLightingMode(0)
    client.fullbright_enabled = false
  end
end
