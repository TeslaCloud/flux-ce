--- Opens and closes the tab menu from code. The tab menu is the full screen menu that takes
-- the place of the scoreboard (the `fl_tab_menu` panel, or whatever the active theme has
-- registered as its 'tab_menu' panel); the gamemode opens it with `Flux.TabMenu:open` when
-- the scoreboard key is pressed and plugins can do the same, for example to bring the
-- player to their inventory. The menu that is open is kept in `Flux.tab_menu`.
-- `OnTabMenuOpened` and `OnTabMenuClosed` are run when it opens and closes. The server
-- reaches the menu of a player through `Player:open_tab_menu` and `Player:close_tab_menu`.
-- @module [Flux.TabMenu]

mod 'Flux::TabMenu'

local IsValid  = IsValid
local isstring = isstring

--- Returns the tab menu if it is open. A menu that is playing its closing animation does
-- not count as open any more.
-- @return [Panel the tab menu, or nil if it is not open]
function Flux.TabMenu:get_panel()
  local menu = Flux.tab_menu

  if IsValid(menu) and !menu.closing then
    return menu
  end
end

--- Checks whether the tab menu is open.
-- @return [Boolean]
function Flux.TabMenu:is_open()
  return self:get_panel() != nil
end

--- Opens the tab menu, or returns the one that is open already. Without an item the menu
-- shows the one that was open the last time, or its default one.
-- ```
-- -- Open the tab menu on the inventory.
-- Flux.TabMenu:open('inventory')
-- ```
-- @param panel_id=nil [String ID of the menu item to show, as it was given to the menu's
--   add_menu_item; the menu falls back to its default item if there is no such item]
-- @return [Panel the tab menu, or nil if it could not be opened: the local player is not
--   ready yet, a ShouldScoreboardShow handler has returned false or the theme has not
--   created the panel]
function Flux.TabMenu:open(panel_id)
  if !IsValid(PLAYER) then return end

  local menu = self:get_panel()

  if menu then
    if isstring(panel_id) and menu.open_panel then
      menu:open_panel(panel_id)
    end

    return menu
  end

  --- Asks whether the tab menu may open. Called on the client when the scoreboard key is
  -- pressed and when the menu is opened from code with `Flux.TabMenu:open`.
  -- @return [Boolean Return false to keep the tab menu from opening]
  if hook.Run('ShouldScoreboardShow') == false then return end

  if isstring(panel_id) then
    PLAYER.tab_panel = panel_id
  end

  menu = Theme.create_panel('tab_menu', nil, 'fl_tab_menu')

  if !IsValid(menu) then return end

  Flux.tab_menu = menu

  menu:MakePopup()

  --- Called on the client when the tab menu has been opened, with the scoreboard key or
  -- from code, after its buttons have been created and the item it starts on has been
  -- shown (`OnMenuPanelOpen` has run for that one already).
  -- @param menu [Panel The tab menu that has been opened]
  hook.Run('OnTabMenuOpened', menu)

  return menu
end

--- Closes the tab menu if it is open. The menu plays its closing animation and is removed
-- afterwards.
-- @return [Boolean true if the menu was open and has been told to close]
function Flux.TabMenu:close()
  local menu = self:get_panel()

  if !menu or !menu.close_menu then return false end

  menu:close_menu()

  return true
end

Cable.receive('fl_tab_menu_open', function(panel_id)
  Flux.TabMenu:open(isstring(panel_id) and panel_id or nil)
end)

Cable.receive('fl_tab_menu_close', function()
  Flux.TabMenu:close()
end)
