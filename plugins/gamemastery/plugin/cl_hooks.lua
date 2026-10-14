--- Client hooks of the Gamemastery plugin: the gamemaster entry of the tab menu, the buttons
-- of the main menu that lead back to gamemaster mode and create pool characters, and the
-- indicator of gamemaster mode on the HUD.

--- Adds the gamemaster panel to the tab menu of players with the 'gamemastery' permission.
-- @param menu [Panel the tab menu]
function Gamemastery:AddTabMenuItems(menu)
  if !PLAYER:can('gamemastery') then return end

  menu:add_menu_item('gamemaster', {
    title = t'ui.gamemastery.tab_menu',
    panel = 'fl_gamemaster_panel',
    icon = 'fa-hat-wizard',
    priority = 35
  })
end

--- Adds a button that returns a gamemaster to gamemaster mode: it closes the main menu for a
-- gamemaster without a character, and releases the pool character of a gamemaster whose
-- pool character has been banned, who is kept dead until they drop it. For gamemasters who
-- are not of the `gamemaster` role it also adds a button that opens the character creation
-- screen for a pool character.
-- @param panel [Panel the main menu]
-- @param sidebar [Panel the main menu sidebar]
function Gamemastery:AddMainMenuItems(panel, sidebar)
  if !PLAYER:can('gamemastery') then return end

  local possessing_banned = PLAYER:is_character_loaded() and PLAYER:is_character_banned() and
    Gamemastery.find_character(PLAYER:get_character_id()) != nil

  if !PLAYER:is_character_loaded() or possessing_banned then
    panel:add_button(t'ui.gamemastery.main_menu.return', function(btn)
      if possessing_banned then
        Gamemastery.request_release()
      end

      panel:Remove()
    end)
  end

  if Gamemastery.has_gamemaster_role(PLAYER) then return end

  panel:add_button(t'ui.gamemastery.main_menu.create', function(btn)
    btn:set_enabled(false)

    panel.menu = Theme.create_panel('char_create', panel)
    panel.menu:set_extra_data({ gamemaster = true })
    panel.menu:SetPos(ScrW(), 0)
    panel.menu:MoveTo(0, 0, Theme.get_option('menu_anim_duration'), 0.25, 0.5)

    panel.sidebar:MoveTo(
      -panel.sidebar:GetWide(),
      Theme.get_option('menu_sidebar_y'),
      Theme.get_option('menu_anim_duration'),
      0.25,
      0.5
    )
  end)
end

--- Draws the gamemaster mode indicator in the bottom right corner, above the vanish
-- indicator, while the local player is in gamemaster mode.
function Gamemastery:HUDPaint()
  local client = PLAYER

  if !IsValid(client) or !client:has_initialized() or !client:get_nv('gamemastering') then return end

  local text, font = t'ui.gamemastery.hud', Theme.get_font('text_normal')
  local w, h = util.text_size(text, font)
  local x, y = ScrW() - w - 16, ScrH() - h * 2 - 16 - math.scale(8)

  FontAwesome:draw('fa-hat-wizard', x - h - math.scale(12), y, h)
  draw.SimpleText(text, font, x, y, color_white)
end
