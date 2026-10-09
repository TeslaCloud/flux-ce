--- Client side of the Classes plugin: adds the Classes tab to the tab menu and supplies the
-- error text for a character that could not be created because of its class.

--- Adds the Classes tab to the tab menu when the faction of the local player has classes.
-- When it has none, the tab is also forgotten as the one to reopen, since the tab menu
-- expects the tab it reopens to exist.
-- @param menu [Panel the tab menu]
function Classes:AddTabMenuItems(menu)
  if #self.get_faction_classes(PLAYER:get_faction_id()) == 0 then
    if PLAYER.tab_panel == 'classes' then
      PLAYER.tab_panel = nil
    end

    return
  end

  menu:add_menu_item('classes', {
    title = t'ui.tab_menu.classes',
    panel = 'fl_classes',
    icon = 'fa-id-badge',
    priority = 25
  })
end

--- Supplies the error text shown when character creation fails because of the class.
-- @param success [Boolean]
-- @param status [Number CHAR_* status code sent by the server]
-- @return [String translated error for CHAR_ERR_CLASS, otherwise nil]
function Classes:GetCharCreationErrorText(success, status)
  if status == CHAR_ERR_CLASS then
    return t'error.class.not_selected'
  end
end
