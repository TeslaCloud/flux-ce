function Bolt:PlayerStartVoice(player)
  if !player:can('voice') then
    return false
  end
end

function Bolt:AddTabMenuItems(menu)
  menu:add_menu_item('admin', {
    title = 'Admin',
    panel = 'fl_admin_panel',
    icon = 'fa-user-shield'
  })
end

function Bolt:AddAdminMenuItems(panel, sidebar)
  panel:add_panel('admin_player_management', t'admin.player_management', 'manage_permissions')
  panel:add_panel('admin_config_editor', t'admin.config_editor', 'manage_config')
end

function Bolt:OnThemeLoaded(current_theme)
  current_theme:add_panel('admin_player_management', function(id, parent, ...)
    return vgui.Create('fl_player_management', parent)
  end)

  current_theme:add_panel('admin_config_editor', function(id, parent, ...)
    return vgui.Create('fl_config_editor', parent)
  end)
end

function Bolt:HUDPaint()
  if IsValid(fl.client) and fl.client:has_initialized() and fl.client:Alive()
  and fl.client:get_nv('transmission_prevented') then
    local text = t'vanish.client_text'
    local font = theme.get_font('text_normal')
    local w, h = util.text_size(text, font)
    draw.SimpleText(text, font, ScrW() - w - 16, ScrH() - h - 16, color_white)
  end
end
