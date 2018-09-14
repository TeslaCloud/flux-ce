function flAttributes:OnThemeLoaded(current_theme)
  current_theme:AddPanel("CharCreation_Attributes", function(id, parent, ...)
    return vgui.Create("flCharCreationAttributes", parent)
  end)
end

function flAttributes:AddCharacterCreationMenuItems(panel, menu, sidebar)
  menu:add_button('attributes', function(btn)
    panel:OpenPanel("CharCreation_Attributes")
  end)
end
