--- Returns false for speakers that lack the 'voice' permission.
-- @param player [Player the player that started talking]
-- @return [Boolean false if the player lacks the permission, nothing otherwise]
function Bolt:PlayerStartVoice(player)
  if !player:can('voice') then
    return false
  end
end

--- Adds the Admin entry to the tab menu.
-- @param menu [Panel the tab menu]
function Bolt:AddTabMenuItems(menu)
  menu:add_menu_item('admin', {
    title = 'Admin',
    panel = 'fl_admin_panel',
    icon = 'fa-shield-alt',
    priority = 40
  })
end

--- Adds the player management and config editor pages to the admin panel.
-- @param panel [Panel the admin panel]
-- @param sidebar [Panel the admin panel's sidebar]
function Bolt:AddAdminMenuItems(panel, sidebar)
  panel:add_panel('admin_player_management', t'ui.admin.player_management', 'manage_permissions')
  panel:add_panel('admin_config_editor', t'ui.admin.config_editor', 'manage_configuration')
end

--- Registers the constructors of the admin panel's pages with the loaded theme.
-- @param current_theme [ThemeBase]
function Bolt:OnThemeLoaded(current_theme)
  current_theme:add_panel('admin_player_management', function(id, parent, ...)
    return vgui.Create('fl_player_management', parent)
  end)

  current_theme:add_panel('admin_config_editor', function(id, parent, ...)
    return vgui.Create('fl_config_editor', parent)
  end)
end

--- Draws the vanish indicator in the bottom right corner while the local player is hidden
-- from other players.
function Bolt:HUDPaint()
  if IsValid(PLAYER) and PLAYER:has_initialized() and PLAYER:Alive()
  and PLAYER:get_nv('transmission_prevented') then
    local text, font = t'ui.hud.vanish', Theme.get_font('text_normal')
    local w, h = util.text_size(text, font)
    local x, y = ScrW() - w - 16, ScrH() - h - 16
    FontAwesome:draw('fa-eye-slash', x - h - math.scale(12), y, h)
    draw.SimpleText(text, font, x, y, color_white)
  end
end

--- Switches to fullbright lighting when the local player's 'should_fullbright' net var is set.
function Bolt:PostRender()
  if IsValid(PLAYER) and PLAYER:get_nv('should_fullbright') then
    render.SetLightingMode(1)
    PLAYER.fullbright_enabled = true
  end
end

--- Restores normal lighting before the HUD is drawn if fullbright was switched on.
function Bolt:PreDrawHUD()
  if IsValid(PLAYER) and PLAYER.fullbright_enabled then
    render.SetLightingMode(0)
    PLAYER.fullbright_enabled = false
  end
end
