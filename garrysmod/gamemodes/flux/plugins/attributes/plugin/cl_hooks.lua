function flAttributes:OnThemeLoaded(current_theme)
  current_theme:AddPanel('CharCreation_Attributes', function(id, parent, ...)
    return vgui.Create('flCharCreationAttributes', parent)
  end)
end

function flAttributes:AddCharacterCreationMenuStages(panel)
  panel:add_stage('CharCreation_Attributes')
end
