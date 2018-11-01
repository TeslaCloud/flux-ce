do
  local cur_volume = 1

  function Characters:Tick()
    if fl.menu_music then
      if !system.HasFocus() then
        fl.menu_music:SetVolume(0)
      else
        fl.menu_music:SetVolume(cur_volume)
      end

      if !IsValid(fl.intro_panel) then
        if cur_volume > 0.05 then
          cur_volume = Lerp(0.1, cur_volume, 0)
          fl.menu_music:SetVolume(cur_volume)
        else
          cur_volume = 1
          fl.menu_music:Stop()
          fl.menu_music = nil
        end
      end
    end
  end
end

function Characters:PlayerInitialized()
  if !fl.client:get_character() and !IsValid(fl.intro_panel) then
    fl.intro_panel = vgui.Create('flIntro')

    if IsValid(fl.intro_panel) then
      fl.intro_panel:MakePopup()
    end
  end
end

function Characters:OnIntroPanelRemoved()
  if !fl.client:get_character() then
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

function Characters:OnThemeLoaded(current_theme)
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

function Characters:AddTabMenuItems(menu)
  menu:add_menu_item('mainmenu', {
    title = t'tab_menu.main_menu',
    icon = 'fa-users',
    override = function(menu_panel, button)
      menu_panel:safe_remove()
      fl.intro_panel = theme.create_panel('main_menu')
    end
  }, 1)
end

function Characters:PostCharacterLoaded(char_id)
  if IsValid(fl.intro_panel) then
    fl.intro_panel:safe_remove()
  end
end

function Characters:ShouldDrawLoadingScreen()
  if !fl.intro_panel then
    return true
  end
end

function Characters:ShouldHUDPaint()
  return fl.client:is_character_loaded()
end

function Characters:ShouldScoreboardHide()
  return fl.client:is_character_loaded()
end

function Characters:ShouldScoreboardShow()
  return fl.client:is_character_loaded()
end

function Characters:RebuildScoreboardPlayerCard(card, player)
  local x, y = card.name_label:GetPos()
  local oldX = x

  x = x + font.scale(32) + 4

  card.name_label:SetPos(x, 2)

  if IsValid(card.desc_label) then
    card.desc_label:safe_remove()
    card.spawn_icon:safe_remove()
  end

  card.spawn_icon = vgui.Create('SpawnIcon', card)
  card.spawn_icon:SetPos(oldX - 4, 4)
  card.spawn_icon:SetSize(32, 32)
  card.spawn_icon:SetModel(player:GetModel())

  local phys_desc = player:get_phys_desc()

  if phys_desc:utf8len() > 64 then
    phys_desc = phys_desc:utf8sub(1, 64)..'...'
  end

  card.desc_label = vgui.Create('DLabel', card)
  card.desc_label:SetText(phys_desc)
  card.desc_label:SetFont(theme.get_font('text_smaller'))
  card.desc_label:SetPos(x, card.name_label:GetTall())
  card.desc_label:SetTextColor(theme.get_color('text'))
  card.desc_label:SizeToContents()
end

function Characters:AddCharacterCreationMenuStages(panel)
  panel:add_stage('char_create.general')
end

function Characters:AddMainMenuItems(panel, sidebar)
  local scrw, scrh = ScrW(), ScrH()

  if fl.client:get_character() then
    panel:add_button(t'main_menu.continue', function(btn)
      panel:Remove()
    end)
  end

  panel:add_button(t'char_create.title', function(btn)
    panel.menu = theme.create_panel('character_creation', panel)
    panel.menu:SetPos(ScrW(), 0)
    panel.menu:MoveTo(0, 0, theme.get_option('menu_anim_duration'), 0.25, 0.5)

    panel.sidebar:MoveTo(-panel.sidebar:GetWide(), theme.get_option('menu_sidebar_y'), theme.get_option('menu_anim_duration'), 0.25, 0.5)
  end)

  if #fl.client:get_all_characters() > 0 then
    panel:add_button(t'char_create.load', function(btn)
      panel.menu = theme.create_panel('char_create.load', panel)
      panel.menu:SetPos(-panel.menu:GetWide(), 0)
      panel.menu:MoveTo(0, 0, theme.get_option('menu_anim_duration'), 0.25, 0.5)

      panel.sidebar:MoveTo(ScrW(), theme.get_option('menu_sidebar_y'), theme.get_option('menu_anim_duration'), 0.25, 0.5)
    end)
  end

  panel:add_button(t'main_menu.disconnect', function(btn)
    Derma_Query(t'main_menu.disconnect_msg', t'main_menu.disconnect_msg', t'yes', function()
      RunConsoleCommand('disconnect')
    end,
    t'no')
  end)
end

function Characters:PanelCharacterSet(panel, char_data)
  panel.model.Entity:SetSkin(char_data.skin or 1)
end

cable.receive('PlayerCreatedCharacter', function(success, status)
  if IsValid(fl.intro_panel) and IsValid(fl.intro_panel.menu) then
    if success then
      fl.intro_panel.menu:goto_stage(-1)
      fl.intro_panel.menu:clear_data()

      timer.Simple(theme.get_option('menu_anim_duration') * #fl.intro_panel.menu.stages, function()
        local chars = fl.client:get_all_characters()

        if #chars == 1 then
          cable.send('PlayerSelectCharacter', chars[1].character_id)
        end
      end)
    else
      local text = 'We were unable to create a character! (unknown error)'
      local hook_text = hook.run('GetCharCreationErrorText', success, status)

      if hook_text then
        text = hook_text
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
