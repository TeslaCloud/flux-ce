--- Client-side hooks of Bolt, registered as `Bolt`: the Admin entry of the tab menu and its
-- pages, keeping the config editor, the plugin manager, the permission editor and the player
-- management page up to date with the server, fullbright rendering and the voice permission
-- check.

local IsValid = IsValid

--- Bolt's pages of the admin panel, in their order: the ID under which the theme creates the
-- page, the phrase of its title and the permission that opens it, nil for the config editor,
-- which takes the permission named by `Config.permission`.
local admin_pages = {
  { 'admin_player_management', 'ui.admin.player_management', 'manage_permissions' },
  { 'admin_staff_list', 'ui.admin.staff.title', 'manage_permissions' },
  { 'admin_ban_list', 'ui.admin.bans.title', 'ban' },
  { 'admin_config_editor', 'ui.admin.config_editor' },
  { 'admin_plugin_manager', 'ui.admin.plugins.title', 'manage_plugins' }
}

local hooks = {}

--- Returns false for speakers that lack the 'voice' permission.
-- @param speaker [Player the player that started talking]
-- @return [Boolean false if the player lacks the permission, nothing otherwise]
function hooks:PlayerStartVoice(speaker)
  if !speaker:can('voice') then
    return false
  end
end

--- Checks whether the local player may open at least one of Bolt's pages of the admin panel.
-- @return [Boolean]
local function can_open_admin_page()
  for _, page in ipairs(admin_pages) do
    if PLAYER:can(page[3] or Config.permission) then
      return true
    end
  end

  return false
end

--- Adds the Admin entry to the tab menu for a player who may open at least one of Bolt's
-- pages of the admin panel.
-- @param menu [Panel the tab menu]
function hooks:AddTabMenuItems(menu)
  if !can_open_admin_page() then return end

  menu:add_menu_item('admin', {
    title = t'ui.tab_menu.admin',
    panel = 'fl_admin_panel',
    icon = 'fa-shield-alt',
    priority = 40
  })
end

--- Adds Bolt's pages to the admin panel: player management, the staff list, the ban list,
-- the config editor and the plugin manager. Each one asks for the permission that opens it:
-- `manage_permissions` for the player management and the staff pages, whose changes the
-- server checks against the permissions of the commands that make the same changes (`role`,
-- `permission` and `charpermission`), `ban` for the ban list, the permission named by
-- `Config.permission` for the config editor and `manage_plugins` for the plugin manager.
-- @param panel [Panel the admin panel]
-- @param _sidebar [Panel the admin panel's sidebar]
function hooks:AddAdminMenuItems(panel, _sidebar)
  for _, page in ipairs(admin_pages) do
    panel:add_panel(page[1], t(page[2]), page[3] or Config.permission)
  end
end

--- Registers the constructors of the admin panel's pages with the loaded theme.
-- @param current_theme [ThemeBase]
function hooks:ThemeLoaded(current_theme)
  current_theme:add_panel('admin_player_management', function(_id, parent, ...)
    return vgui.Create('fl_player_management', parent)
  end)

  current_theme:add_panel('admin_staff_list', function(_id, parent, ...)
    return vgui.Create('fl_staff_list', parent)
  end)

  current_theme:add_panel('admin_ban_list', function(_id, parent, ...)
    return vgui.Create('fl_ban_list', parent)
  end)

  current_theme:add_panel('admin_config_editor', function(_id, parent, ...)
    return vgui.Create('fl_config_editor', parent)
  end)

  current_theme:add_panel('admin_plugin_manager', function(_id, parent, ...)
    return vgui.Create('fl_plugin_manager', parent)
  end)
end

--- Updates the line of a config in the config editor, if it is open, when the value of
-- the config has arrived from the server. When `bolt_external_admin` arrives with a mode the
-- client has not applied yet, `Bolt:setup_cami` applies it.
-- @param key [String config key]
-- @param _old_value [Any value the client had before]
-- @param _new_value [Any value that has been received]
function hooks:ConfigReceived(key, _old_value, _new_value)
  if key == 'bolt_external_admin' and Bolt.cami_mode != Bolt:get_cami_mode() then
    Bolt:setup_cami()
  end

  if IsValid(Bolt.config_editor) then
    Bolt.config_editor:update_config(key)
  end
end

--- Updates the line of a config in the config editor, if it is open, when the server
-- reports that the config has got a pending value or no longer has one.
-- @param key [String config key]
-- @param _is_pending [Boolean whether the config has a pending value now]
-- @param _value [Any value the config takes on the next start of the server]
function hooks:ConfigPendingReceived(key, _is_pending, _value)
  if IsValid(Bolt.config_editor) then
    Bolt.config_editor:update_config(key)
  end
end

--- Rebuilds the list of the plugin manager, if it is open, when the server reports that a
-- plugin has been disabled or enabled.
-- @param _id [String normalized ID of the plugin]
-- @param _disabled [Boolean true if the plugin will be disabled after the restart]
function hooks:PluginStateChanged(_id, _disabled)
  if IsValid(Bolt.plugin_manager) then
    Bolt.plugin_manager:rebuild()
  end
end

--- Lets the permission editor and the header of the player management page, if they are
-- open, follow the changes to the role, the permissions and the active character of the
-- player they show.
-- @param entity [Entity the entity whose networked variable has changed]
-- @param key [String name of the variable]
-- @param _old_value [Any previous value]
-- @param _new_value [Any new value]
function hooks:NetVarChanged(entity, key, _old_value, _new_value)
  if IsValid(Bolt.permissions_editor) then
    Bolt.permissions_editor:on_net_var_changed(entity, key)
  end

  if IsValid(Bolt.player_info) then
    Bolt.player_info:on_net_var_changed(entity, key)
  end
end

--- Adds a player who has joined to the list of the player management page, if it is open.
-- @param _actor [Player the player who has joined]
function hooks:PlayerInitialSpawn(_actor)
  if IsValid(Bolt.player_management) then
    Bolt.player_management:rebuild_list()
  end
end

--- Takes a player who is leaving off the list of the player management page, if it is open.
-- @param actor [Player the player who is leaving]
function hooks:PlayerDisconnected(actor)
  if IsValid(Bolt.player_management) then
    Bolt.player_management:rebuild_list(actor)
  end
end

--- Switches to fullbright lighting when the local player's 'should_fullbright' net var is set.
function hooks:PostRender()
  local client = PLAYER

  if IsValid(client) and client:get_nv('should_fullbright') then
    render.SetLightingMode(1)
    client.fullbright_enabled = true
  end
end

--- Restores normal lighting before the HUD is drawn if fullbright was switched on.
function hooks:PreDrawHUD()
  local client = PLAYER

  if IsValid(client) and client.fullbright_enabled then
    render.SetLightingMode(0)
    client.fullbright_enabled = false
  end
end

Plugin.add_hooks('Bolt', hooks)
