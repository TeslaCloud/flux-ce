do
  local cur_volume = 1

  --- Mutes the menu music while the game window is unfocused and fades it out and stops it
  -- once the intro panel is gone.
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

--- Opens the intro panel if the local player has no active character.
function Characters:PlayerInitialized()
  if !PLAYER:is_character_loaded() and !IsValid(Flux.intro_panel) then
    Flux.intro_panel = vgui.Create('fl_intro')

    if IsValid(Flux.intro_panel) then
      Flux.intro_panel:MakePopup()
    end
  end
end

--- Holds the loading screen at 75% until the character list has arrived from the server.
-- @return [String message, Number percentage; nothing once the characters have arrived]
function Characters:GetLoadingScreenMessage()
  if !IsValid(PLAYER) or !istable(PLAYER.characters) then
    return t'ui.hud.loading.characters', 75
  end
end

--- Makes the mapscene render while the intro panel or main menu is open.
-- @return [Boolean true while the panel is valid, otherwise nil]
function Characters:ShouldMapsceneRender()
  if IsValid(Flux.intro_panel) then
    return true
  end
end

--- Opens the main menu after the intro if the local player has no character, retrying on a
-- timer until the panel can be created.
function Characters:OnIntroPanelRemoved()
  if !PLAYER:get_character() then
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

--- Registers the main menu and character creation panels with the theme, and recreates the
-- main menu if it is currently open.
-- @param current_theme [ThemeBase]
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

  current_theme:add_panel('ui.char_create.general', function(id, parent, ...)
    return vgui.Create('fl_char_create_general', parent)
  end)

  if IsValid(Flux.intro_panel) then
    Flux.intro_panel:Remove()

    Flux.intro_panel = Theme.create_panel('main_menu')
    Flux.intro_panel:MakePopup()
  end
end

--- Adds the main menu entry to the tab menu.
-- @param menu [Panel the tab menu]
function Characters:AddTabMenuItems(menu)
  menu:add_menu_item('mainmenu', {
    title = t'ui.tab_menu.main_menu',
    icon = 'fa-bars',
    priority = 10,
    override = function(menu_panel, button)
      menu_panel:safe_remove()
      Flux.intro_panel = Theme.create_panel('main_menu')
    end
  }, 1)
end

--- Closes the main menu after a character has been loaded.
-- @param char_id [Number]
function Characters:PostCharacterLoaded(char_id)
  if IsValid(Flux.intro_panel) then
    Flux.intro_panel:safe_remove()
  end
end

--- Keeps the loading screen visible until the intro panel has been created.
-- @return [Boolean true while there is no intro panel, otherwise nil]
function Characters:ShouldDrawLoadingScreen()
  if !Flux.intro_panel then
    return true
  end
end

--- Hides the HUD while the local player has no active character.
-- @return [Boolean false when no character is loaded, otherwise nil]
function Characters:ShouldHUDPaint()
  if !PLAYER:is_character_loaded() then
    return false
  end
end

--- Lets the scoreboard hide only when the local player has an active character.
-- @return [Boolean]
function Characters:ShouldScoreboardHide()
  return PLAYER:is_character_loaded()
end

--- Lets the scoreboard show only when the local player has an active character.
-- @return [Boolean]
function Characters:ShouldScoreboardShow()
  return PLAYER:is_character_loaded()
end

--- Adds the Steam name to a scoreboard player card and, unless an IsCharacterCardVisible hook
-- returns false, the player's model icon and physical description.
-- @param card [Panel the scoreboard player card]
-- @param target [Player]
function Characters:RebuildScoreboardPlayerCard(card, target)
  local x, y = card.name_label:GetPos()
  local text = target:steam_name()
  local font = Theme.get_font('text_normal')
  local text_height = util.text_height(text, font)

  card.steam_name = vgui.Create('DLabel', card)
  card.steam_name:SetText(text)
  card.steam_name:SetFont(font)
  card.steam_name:SetTextColor(Theme.get_color('text'))
  card.steam_name:SizeToContents()

  if hook.run('IsCharacterCardVisible', card, target) != false then
    card.avatar_panel:SetPos(card:GetWide() - card.avatar_panel:GetWide() - math.scale(48), math.scale(4))

    card.steam_name:SetText(card.steam_name:GetText())
    card.steam_name:SizeToContents()
    card.steam_name:SetPos(card.avatar_panel.x - card.steam_name:GetWide() - math.scale(4), card:GetTall() * 0.5 - text_height * 0.5)

    if IsValid(card.desc_label) then
      card.desc_label:safe_remove()
      card.spawn_icon:safe_remove()
    end

    card.spawn_icon = vgui.Create('SpawnIcon', card)
    card.spawn_icon:SetPos(math.scale_size(4, 4))
    card.spawn_icon:SetSize(math.scale_size(32, 32))
    card.spawn_icon:SetModel(target:GetModel())
    card.spawn_icon:SetEnabled(false)

    local phys_desc = target:get_phys_desc()

    if utf8.len(phys_desc) > 128 then
      phys_desc = phys_desc:utf8sub(1, 128)..'...'
    end

    card.desc_label = vgui.Create('DLabel', card)
    card.desc_label:SetText(phys_desc)
    card.desc_label:SetFont(Theme.get_font('text_smallest'))
    card.desc_label:SetTextColor(Theme.get_color('text'):darken(50))
    card.desc_label:SizeToContents()
    card.desc_label:SetPos(card.name_label.x, card.name_label.y + card.name_label:GetTall())
  else
    card.steam_name:SetPos(math.scale(48), card:GetTall() * 0.5 - text_height * 0.6)
    card.name_label:SetVisible(false)
  end
end

--- Adds the general stage (gender, name, description and model) to character creation.
-- @param panel [Panel the character creation menu]
function Characters:AddCharacterCreationMenuStages(panel)
  panel:add_stage('ui.char_create.general')
end

--- Adds the physical description to the lines drawn when looking at a player.
-- @param target [Player]
-- @param x [Number]
-- @param y [Number]
-- @param distance [Number]
-- @param lines [Map line definitions keyed by ID, modified in place]
function Characters:GetDrawPlayerInfo(target, x, y, distance, lines)
  lines['desc'] = {
    text = target:get_phys_desc(),
    font = Theme.get_font('tooltip_small'),
    color = Color('white'),
    priority = 200
  }
end

--- Adds the continue, create character, load character and disconnect buttons to the main
-- menu.
-- @param panel [Panel the main menu]
-- @param sidebar [Panel the main menu sidebar]
function Characters:AddMainMenuItems(panel, sidebar)
  local scrw, scrh = ScrW(), ScrH()

  if PLAYER:is_character_loaded() then
    panel:add_button(t'ui.main_menu.continue', function(btn)
      panel:Remove()
    end)
  end

  panel:add_button(t'ui.char_create.title', function(btn)
    btn:set_enabled(false)

    panel.menu = Theme.create_panel('char_create', panel)
    panel.menu:SetPos(ScrW(), 0)
    panel.menu:MoveTo(0, 0, Theme.get_option('menu_anim_duration'), 0.25, 0.5)

    panel.sidebar:MoveTo(-panel.sidebar:GetWide(), Theme.get_option('menu_sidebar_y'), Theme.get_option('menu_anim_duration'), 0.25, 0.5)
  end)

  if PLAYER:get_all_characters() and #PLAYER:get_all_characters() > 0 then
    panel:add_button(t'ui.char_create.load', function(btn)
      btn:set_enabled(false)

      panel.menu = Theme.create_panel('char_create.load', panel)
      panel.menu:SetPos(-panel.menu:GetWide(), 0)
      panel.menu:MoveTo(0, 0, Theme.get_option('menu_anim_duration'), 0.25, 0.5)

      panel.sidebar:MoveTo(ScrW(), Theme.get_option('menu_sidebar_y'), Theme.get_option('menu_anim_duration'), 0.25, 0.5)
    end)
  end

  panel:add_button(t'ui.main_menu.disconnect', function(btn)
    Derma_Query(t'ui.main_menu.disconnect_msg', t'ui.main_menu.disconnect', t'ui.yes', function()
      RunConsoleCommand('disconnect')
    end,
    t'ui.no')
  end)
end

--- Applies the character's skin to the model shown in a character panel.
-- @param panel [Panel the character panel]
-- @param char_data [Map networked character data]
function Characters:PanelCharacterSet(panel, char_data)
  panel.model.Entity:SetSkin(char_data.skin or 1)
end
