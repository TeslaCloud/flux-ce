do
  local cur_volume = 1

  function Characters:Tick()
    if Flux.menu_music then
      if !system.HasFocus() then
        Flux.menu_music:SetVolume(0)
      else
        Flux.menu_music:SetVolume(cur_volume)
      end

      if !IsValid(Flux.intro_panel) then
        if cur_volume > 0.05 then
          cur_volume = Lerp(0.1, cur_volume, 0)
          Flux.menu_music:SetVolume(cur_volume)
        else
          cur_volume = 1
          Flux.menu_music:Stop()
          Flux.menu_music = nil
        end
      end
    end
  end
end

function Characters:PlayerInitialized()
  if !Flux.client:get_character() and !IsValid(Flux.intro_panel) then
    Flux.intro_panel = vgui.Create('fl_intro')

    if IsValid(Flux.intro_panel) then
      Flux.intro_panel:MakePopup()
    end
  end
end

function Characters:GetLoadingScreenMessage()
  if !Flux.client.characters then
    return t'loading.characters', 75
  end
end

function Characters:ShouldMapsceneRender()
  if IsValid(Flux.intro_panel) then
    return true
  end
end

function Characters:OnIntroPanelRemoved()
  if !Flux.client:get_character() then
    Flux.intro_panel = Theme.create_panel('main_menu')

    if IsValid(Flux.intro_panel) then
      Flux.intro_panel:MakePopup()
    else
      timer.Create('fl_create_main_panel', 0.1, 0, function()
        Flux.intro_panel = Theme.create_panel('main_menu')

        if IsValid(Flux.intro_panel) then
          Flux.intro_panel:MakePopup()

          timer.Remove('fl_create_main_panel')
        end
      end)
    end
  end
end

function Characters:OnThemeLoaded(current_theme)
  current_theme:add_panel('main_menu', function(id, parent, ...)
    return vgui.Create('fl_main_menu', parent)
  end)

  current_theme:add_panel('char_create', function(id, parent, ...)
    return vgui.Create('fl_char_create', parent)
  end)

  current_theme:add_panel('char_create.load', function(id, parent, ...)
    return vgui.Create('fl_char_load', parent)
  end)

  current_theme:add_panel('char_create.general', function(id, parent, ...)
    return vgui.Create('fl_char_create_general', parent)
  end)

  if IsValid(Flux.intro_panel) then
    Flux.intro_panel:Remove()

    Flux.intro_panel = Theme.create_panel('main_menu')
    Flux.intro_panel:MakePopup()
  end
end

function Characters:AddTabMenuItems(menu)
  menu:add_menu_item('mainmenu', {
    title = t'tab_menu.main_menu',
    icon = 'fa-users',
    override = function(menu_panel, button)
      menu_panel:safe_remove()
      Flux.intro_panel = Theme.create_panel('main_menu')
    end
  }, 1)
end

function Characters:PostCharacterLoaded(char_id)
  if IsValid(Flux.intro_panel) then
    Flux.intro_panel:safe_remove()
  end
end

function Characters:ShouldDrawLoadingScreen()
  if !Flux.intro_panel then
    return true
  end
end

function Characters:ShouldHUDPaint()
  if !Flux.client:is_character_loaded() then
    return false
  end
end

function Characters:ShouldScoreboardHide()
  return Flux.client:is_character_loaded()
end

function Characters:ShouldScoreboardShow()
  return Flux.client:is_character_loaded()
end

function Characters:RebuildScoreboardPlayerCard(card, player)
  local x, y = card.name_label:GetPos()
  local oldX = x

  x = x + Font.scale(32) + 4

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

  if utf8.len(phys_desc) > 64 then
    phys_desc = phys_desc:utf8sub(1, 64)..'...'
  end

  card.desc_label = vgui.Create('DLabel', card)
  card.desc_label:SetText(phys_desc)
  card.desc_label:SetFont(Theme.get_font('text_smaller'))
  card.desc_label:SetPos(x, card.name_label:GetTall())
  card.desc_label:SetTextColor(Theme.get_color('text'))
  card.desc_label:SizeToContents()
end

function Characters:AddCharacterCreationMenuStages(panel)
  panel:add_stage('char_create.general')
end

function Characters:GetPlayerDrawInfo(player, x, y, distance, lines)
  if distance < 640 then
    local alpha = 255

    if distance > 500 then
      local d = distance - 500
      alpha = math.Clamp((255 * (140 - d) / 140), 0, 255)
    end

    lines['desc'] = {
      text = player:get_phys_desc(),
      font = Theme.get_font('tooltip_small'),
      color = Color(255, 255, 255, alpha),
      priority = 200
    }
  end
end

function Characters:AddMainMenuItems(panel, sidebar)
  local scrw, scrh = ScrW(), ScrH()

  if Flux.client:get_character() then
    panel:add_button(t'main_menu.continue', function(btn)
      panel:Remove()
    end)
  end

  panel:add_button(t'char_create.title', function(btn)
    btn:set_enabled(false)

    panel.menu = Theme.create_panel('char_create', panel)
    panel.menu:SetPos(ScrW(), 0)
    panel.menu:MoveTo(0, 0, Theme.get_option('menu_anim_duration'), 0.25, 0.5)

    panel.sidebar:MoveTo(-panel.sidebar:GetWide(), Theme.get_option('menu_sidebar_y'), Theme.get_option('menu_anim_duration'), 0.25, 0.5)
  end)

  if Flux.client:get_all_characters() and #Flux.client:get_all_characters() > 0 then
    panel:add_button(t'char_create.load', function(btn)
      btn:set_enabled(false)

      panel.menu = Theme.create_panel('char_create.load', panel)
      panel.menu:SetPos(-panel.menu:GetWide(), 0)
      panel.menu:MoveTo(0, 0, Theme.get_option('menu_anim_duration'), 0.25, 0.5)

      panel.sidebar:MoveTo(ScrW(), Theme.get_option('menu_sidebar_y'), Theme.get_option('menu_anim_duration'), 0.25, 0.5)
    end)
  end

  panel:add_button(t'main_menu.disconnect', function(btn)
    Derma_Query(t'main_menu.disconnect_msg', t'main_menu.disconnect', t'yes', function()
      RunConsoleCommand('disconnect')
    end,
    t'no')
  end)
end

function Characters:PanelCharacterSet(panel, char_data)
  panel.model.Entity:SetSkin(char_data.skin or 1)
end

cable.receive('fl_player_created_character', function(success, status)
  if IsValid(Flux.intro_panel) and IsValid(Flux.intro_panel.menu) then
    if success then
      Flux.intro_panel.menu:goto_stage(-1)
      Flux.intro_panel.menu:clear_data()

      timer.Simple(Theme.get_option('menu_anim_duration') * #Flux.intro_panel.menu.stages, function()
        local chars = Flux.client:get_all_characters()

        if #chars == 1 then
          cable.send('fl_player_select_character', chars[1].character_id)
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

      Flux.intro_panel:notify(text)
    end
  end
end)
