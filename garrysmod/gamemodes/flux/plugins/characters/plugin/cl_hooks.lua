function flCharacters:PlayerInitialized()
  if !fl.client:GetCharacter() and !IsValid(fl.intro_panel) then
    fl.intro_panel = vgui.Create('flIntro')

    if IsValid(fl.intro_panel) then
      fl.intro_panel:MakePopup()
    end
  end
end

function flCharacters:OnIntroPanelRemoved()
  if !fl.client:GetCharacter() then
    fl.intro_panel = theme.create_panel('main_menu')

    if IsValid(fl.intro_panel) then
      fl.intro_panel:MakePopup()
    else
      timer.Create('flCreateMainPanel', 0.1, 0, function()
        fl.intro_panel = theme.create_panel('main_menu')

        if IsValid(fl.intro_panel) then
          fl.intro_panel:MakePopup()

          timer.Remove('flCreateMainPanel')
        end
      end)
    end
  end
end

do
  local curVolume = 1

  function flCharacters:Tick()
    if fl.menuMusic then
      if !system.HasFocus() then
        fl.menuMusic:SetVolume(0)
      else
        fl.menuMusic:SetVolume(curVolume)
      end

      if !IsValid(fl.intro_panel) then
        if curVolume > 0.05 then
          curVolume = Lerp(0.1, curVolume, 0)
          fl.menuMusic:SetVolume(curVolume)
        else
          curVolume = 1
          fl.menuMusic:Stop()
          fl.menuMusic = nil
        end
      end
    end
  end
end

function flCharacters:OnThemeLoaded(current_theme)
  current_theme:add_panel('main_menu', function(id, parent, ...)
    return vgui.Create('fl_main_menu', parent)
  end)

  current_theme:add_panel('character_creation', function(id, parent, ...)
    return vgui.Create('fl_character_creation', parent)
  end)

  current_theme:add_panel('char_create.load', function(id, parent, ...)
    return vgui.Create('fl_character_load', parent)
  end)

  current_theme:add_panel('char_create.general', function(id, parent, ...)
    return vgui.Create('fl_character_general', parent)
  end)

  if IsValid(fl.intro_panel) then
    fl.intro_panel:Remove()

    fl.intro_panel = theme.create_panel('main_menu')
    fl.intro_panel:MakePopup()
  end
end

function flCharacters:AddTabMenuItems(menu)
  menu:AddMenuItem('mainmenu', {
    title = t'tab_menu.main_menu',
    icon = 'fa-users',
    override = function(menuPanel, button)
      menuPanel:safe_remove()
      fl.intro_panel = theme.create_panel('main_menu')
    end
  }, 1)
end

function flCharacters:PostCharacterLoaded(nCharID)
  if IsValid(fl.intro_panel) then
    fl.intro_panel:safe_remove()
  end
end

function flCharacters:ShouldDrawLoadingScreen()
  if !fl.intro_panel then
    return true
  end
end

function flCharacters:ShouldHUDPaint()
  return fl.client:CharacterLoaded()
end

function flCharacters:ShouldScoreboardHide()
  return fl.client:CharacterLoaded()
end

function flCharacters:ShouldScoreboardShow()
  return fl.client:CharacterLoaded()
end

function flCharacters:RebuildScoreboardPlayerCard(card, player)
  local x, y = card.nameLabel:GetPos()
  local oldX = x

  x = x + font.Scale(32) + 4

  card.nameLabel:SetPos(x, 2)

  if IsValid(card.descLabel) then
    card.descLabel:safe_remove()
    card.spawnIcon:safe_remove()
  end

  card.spawnIcon = vgui.Create('SpawnIcon', card)
  card.spawnIcon:SetPos(oldX - 4, 4)
  card.spawnIcon:SetSize(32, 32)
  card.spawnIcon:SetModel(player:GetModel())

  local phys_desc = player:GetPhysDesc()

  if phys_desc:utf8len() > 64 then
    phys_desc = phys_desc:utf8sub(1, 64)..'...'
  end

  card.descLabel = vgui.Create('DLabel', card)
  card.descLabel:SetText(phys_desc)
  card.descLabel:SetFont(theme.get_font('text_smaller'))
  card.descLabel:SetPos(x, card.nameLabel:GetTall())
  card.descLabel:SetTextColor(theme.get_color('text'))
  card.descLabel:SizeToContents()
end

function flCharacters:AddCharacterCreationMenuStages(panel)
  panel:add_stage('char_create.general')
end

function flCharacters:AddMainMenuItems(panel, sidebar)
  local scrw, scrh = ScrW(), ScrH()

  if fl.client:GetCharacter() then
    panel:add_button(t'main_menu.continue', function(btn)
      panel:Remove()
    end)
  end

  panel:add_button(t'char_create.title', function(btn)
    panel.menu = theme.create_panel('character_creation', panel)
    panel.menu:SetPos(ScrW(), 0)
    panel.menu:MoveTo(0, 0, theme.get_option('menu_anim_duration'), 0, 0.5)

    panel.sidebar:MoveTo(-panel.sidebar:GetWide(), theme.get_option('menu_sidebar_y'), theme.get_option('menu_anim_duration'), 0, 0.5)
  end)

  if #fl.client:GetAllCharacters() > 0 then
    panel:add_button(t'char_create.load', function(btn)
      panel.menu = theme.create_panel('char_create.load', panel)
      panel.menu:SetPos(-panel.menu:GetWide(), 0)
      panel.menu:MoveTo(0, 0, theme.get_option('menu_anim_duration'), 0, 0.5)
  
      panel.sidebar:MoveTo(ScrW(), theme.get_option('menu_sidebar_y'), theme.get_option('menu_anim_duration'), 0, 0.5)
    end)
  end

  panel:add_button(t'main_menu.disconnect', function(btn)
    Derma_Query(t'main_menu.disconnect_msg', t'main_menu.disconnect_msg', t'yes', function()
      RunConsoleCommand('disconnect')
    end,
    t'no')
  end)
end

function flCharacters:PanelCharacterSet(panel, char_data)
  panel.model.Entity:SetSkin(char_data.skin or 1)
end

netstream.Hook('PlayerCreatedCharacter', function(success, status)
  if IsValid(fl.intro_panel) and IsValid(fl.intro_panel.menu) then
    if success then
      fl.intro_panel.menu:goto_stage(-1)
      fl.intro_panel.menu:ClearData()

      timer.Simple(theme.get_option('menu_anim_duration') * #fl.intro_panel.menu.stages, function()
        local chars = fl.client:GetAllCharacters()

        if #chars == 1 then
          netstream.Start('PlayerSelectCharacter', chars[1].character_id)
        end
      end)
    else
      local text = 'We were unable to create a character! (unknown error)'
      local hookText = hook.run('GetCharCreationErrorText', success, status)

      if hookText then
        text = hookText
      elseif status == CHAR_ERR_NAME then
        text = "Your character's name must be between "..config.get('character_min_name_len')..' and '..config.get('character_max_name_len')..' characters long!'
      elseif status == CHAR_ERR_DESC then
        text = "Your character's description must be between "..config.get('character_min_desc_len')..' and '..config.get('character_max_desc_len')..' characters long!'
      elseif status == CHAR_ERR_GENDER then
        text = 'You must pick a gender for your character before continuing!'
      elseif status == CHAR_ERR_MODEL then
        text = 'You have not chosen a model or the one you have chosen is invalid!'
      end

      fl.intro_panel:notify(text)
    end
  end
end)
