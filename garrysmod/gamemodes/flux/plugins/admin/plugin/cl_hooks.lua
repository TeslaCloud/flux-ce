function flAdmin:AddTabMenuItems(menu)
  menu:AddMenuItem('admin', {
    title = 'Admin',
    panel = 'flAdminPanel',
    icon = 'fa-shield'
  })
end

function flAdmin:PlayerStartVoice(player)
  if !player:can('voice') then
    return false
  end
end
