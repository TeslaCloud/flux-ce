--- Client hook handlers of the Stats plugin: add the stats stage to character creation, word
-- the refusal of a character whose stat levels the server did not accept and add the
-- character sheet to the tab menu as its first and default page.

--- Registers the stats character creation panel and the character sheet with the theme.
-- @param current_theme [Theme theme that was loaded]
function Stats:ThemeLoaded(current_theme)
  current_theme:add_panel('ui.char_create.stats', function(_id, parent, ...)
    return vgui.Create('fl_character_creation_stats', parent)
  end)

  current_theme:add_panel('character_sheet', function(_id, parent, ...)
    return vgui.Create('fl_character_sheet', parent)
  end)
end

--- Adds the character sheet to the tab menu as its first and default page while the local
-- player has a character. Without one the sheet is also forgotten as the page to reopen,
-- since the tab menu expects the page it reopens to exist.
-- @param menu [Panel the tab menu]
function Stats:AddTabMenuItems(menu)
  if !PLAYER:is_character_loaded() then
    if PLAYER.tab_panel == 'character_sheet' then
      PLAYER.tab_panel = nil
    end

    return
  end

  menu:add_menu_item('character_sheet', {
    title = t'ui.tab_menu.character_sheet',
    panel = 'fl_character_sheet',
    icon = 'fa-id-card',
    priority = 5,
    default = true
  })
end

--- Adds the stats stage to character creation.
-- @param panel [Panel character creation menu]
function Stats:AddCharacterCreationMenuStages(panel)
  panel:add_stage('ui.char_create.stats')
end

--- Returns the error text for characters whose attribute points do not add up.
-- @param _success [Boolean whether the character was created]
-- @param status [Number CHAR_ERR_ status code]
-- @return [String error text, nil for other statuses]
function Stats:GetCharacterCreationErrorText(_success, status)
  if status == CHAR_ERR_ATTRIBUTE_SUM then
    return t('error.attribute.sum', { points = Stats:default_attribute_points() })
  end
end
