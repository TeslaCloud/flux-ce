function flAdmin:AddTabMenuItems(menu)
  menu:AddMenuItem('admin', {
    title = 'Admin',
    panel = 'flAdminPanel',
    icon = 'fa-shield'
  })
end
