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
    fl.intro_panel = theme.CreatePanel('MainMenu')

    if IsValid(fl.intro_panel) then
      fl.intro_panel:MakePopup()
    else
      timer.Create('flCreateMainPanel', 0.1, 0, function()
        fl.intro_panel = theme.CreatePanel('MainMenu')

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
  current_theme:AddPanel('MainMenu', function(id, parent, ...)
    return vgui.Create('flMainMenu', parent)
  end)

  current_theme:AddPanel('CharacterCreation', function(id, parent, ...)
    return vgui.Create('flCharacterCreation', parent)
  end)

  current_theme:AddPanel('char_create.load', function(id, parent, ...)
    return vgui.Create('fl_character_load', parent)
  end)

  current_theme:AddPanel('char_create.general', function(id, parent, ...)
    return vgui.Create('flCharCreationGeneral', parent)
  end)

  if IsValid(fl.intro_panel) then
    fl.intro_panel:Remove()

    fl.intro_panel = theme.CreatePanel('MainMenu')
    fl.intro_panel:MakePopup()
  end
end

function flCharacters:AddTabMenuItems(menu)
  menu:AddMenuItem('mainmenu', {
    title = 'Main Menu',
    icon = 'fa-users',
    override = function(menuPanel, button)
      menuPanel:SafeRemove()
      fl.intro_panel = theme.CreatePanel('MainMenu')
    end
  }, 1)
end

function flCharacters:PostCharacterLoaded(nCharID)
  if IsValid(fl.intro_panel) then
    fl.intro_panel:SafeRemove()
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
    card.descLabel:SafeRemove()
    card.spawnIcon:SafeRemove()
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
  card.descLabel:SetFont(theme.GetFont('Text_Smaller'))
  card.descLabel:SetPos(x, card.nameLabel:GetTall())
  card.descLabel:SetTextColor(theme.GetColor('Text'))
  card.descLabel:SizeToContents()
end

function flCharacters:AddCharacterCreationMenuStages(panel)
  panel:add_stage('char_create.general')
end

function flCharacters:AddMainMenuItems(panel, sidebar)
  local scrW, scrH = ScrW(), ScrH()

  panel:add_button(t('main_menu.new'), function(btn)
    panel.menu = theme.CreatePanel('CharacterCreation', panel)
    panel.menu:SetPos(ScrW(), 0)
    panel.menu:MoveTo(0, 0, .5, 0, .5)

    panel.sidebar:MoveTo(-panel.sidebar:GetWide(), theme.GetOption('MainMenu_SidebarY'), .5, 0, .5)
  end)

  if #fl.client:GetAllCharacters() > 0 then
    panel:add_button(t('main_menu.load'), function(btn)
      panel.menu = theme.CreatePanel('char_create.load', panel)
      panel.menu:SetPos(-panel.menu:GetWide(), 0)
      panel.menu:MoveTo(0, 0, .5, 0, .5)
  
      panel.sidebar:MoveTo(ScrW(), theme.GetOption('MainMenu_SidebarY'), .5, 0, .5)

      --[[panel.menu = vgui.Create('DFrame', panel)
      panel.menu:SetPos(scrW * 0.5 - 300, scrH / 4)
      panel.menu:SetSize(600, 600)
      panel.menu:SetTitle('LOAD CHARACTER')

      panel.menu.Paint = function(lp, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
        draw.SimpleText('Which one to load', 'DermaLarge', 0, 24)

        if #fl.client:GetAllCharacters() <= 0 then
          draw.SimpleText('wow you have none', 'DermaLarge', 0, 64)
        end
      end

      panel.menu:MakePopup()

      panel.menu.buttons = {}

      local offY = 0

      for k, v in ipairs(fl.client:GetAllCharacters()) do
        panel.menu.buttons[k] = vgui.Create('DButton', panel.menu)
        panel.menu.buttons[k]:SetPos(8, 100 + offY)
        panel.menu.buttons[k]:SetSize(128, 24)
        panel.menu.buttons[k]:SetText(v.name)
        panel.menu.buttons[k].DoClick = function()
          netstream.Start('PlayerSelectCharacter', v.character_id)
          panel:Remove()
        end

        offY = offY + 28
      end]]
    end)
  end

  if fl.client:GetCharacter() then
    panel:add_button(t('main_menu.cancel'), function(btn)
      panel:Remove()
    end)
  else
    panel:add_button(t('main_menu.disconnect'), function(btn)
      Derma_Query(t('main_menu.disconnect_msg'), t('main_menu.disconnect_msg'), t'yes', function()
        RunConsoleCommand('disconnect')
      end,
      t'no')
    end)
  end
end

netstream.Hook('PlayerCreatedCharacter', function(success, status)
  if IsValid(fl.intro_panel) and IsValid(fl.intro_panel.menu) then
    if success then
      fl.intro_panel.menu:PrevStage()

      timer.Create('flux_char_created', .1, #fl.intro_panel.menu.stages - 1, function()
        fl.intro_panel.menu:PrevStage()
      end)

      fl.intro_panel.menu:ClearData()

      local chars = fl.client:GetAllCharacters()

      if #chars == 1 then
        netstream.Start('PlayerSelectCharacter', chars[1].character_id)
      end
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
