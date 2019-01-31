function Bolt:PlayerStartVoice(player)
  if !player:can('voice') then
    return false
  end
end

function Bolt:AddTabMenuItems(menu)
  menu:add_menu_item('admin', {
    title = 'Admin',
    panel = 'fl_admin_panel',
    icon = 'fa-shield'
  })
end

function Bolt:AddAdminMenuItems(panel, sidebar)
  --sidebar:add_button('Manage Config')
  --sidebar:add_button('Manage Players')
  --sidebar:add_button('Manage Admins')
  --sidebar:add_button('Group Editor')
  --sidebar:add_button('Item Editor')
  panel:add_panel('admin_player_management', 'Player Management', 'manage_permissions')
end

function Bolt:OnThemeLoaded(current_theme)
  current_theme:add_panel('admin_player_management', function(id, parent, ...)
    return vgui.Create('fl_player_management', parent)
  end)
end
