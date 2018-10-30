function Bolt:AddTabMenuItems(menu)
  menu:AddMenuItem('admin', {
    title = 'Admin',
    panel = 'flAdminPanel',
    icon = 'fa-shield'
  })
end

function Bolt:PlayerStartVoice(player)
  if !player:can('voice') then
    return false
  end
end
