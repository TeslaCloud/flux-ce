--- Client side of the interface hooks: the `GM` handlers that make Derma use the Flux skin,
-- create the fonts once the schema has loaded and again when the screen resolution changes,
-- open the tab menu in place of the scoreboard, fill the tab menu and the player menu of
-- the scoreboard, center the panels of the tab menu and flash the game window when the
-- intro appears.

local IsValid = IsValid
local CurTime = CurTime

--- Creates the fonts once the schema has been loaded on the client.
function GM:ClientSchemaLoaded()
  Font.create_fonts()
end

--- Makes Derma use the Flux skin by default.
-- @return [String name of the skin]
function GM:ForceDermaSkin()
  return 'Flux'
end

--- Recreates the fonts so that they fit the new resolution.
-- @param _new_w [Number new screen width]
-- @param _new_h [Number new screen height]
-- @param _old_w [Number previous screen width]
-- @param _old_h [Number previous screen height]
function GM:OnResolutionChanged(_new_w, _new_h, _old_w, _old_h)
  Font.create_fonts()
end

--- Opens the tab menu in place of the default scoreboard, unless the ShouldScoreboardShow
-- hook returns false, and notes when the key was pressed.
function GM:ScoreboardShow()
  local menu = Flux.TabMenu:open()

  if menu then
    menu.held_time = CurTime() + 0.3
  end
end

--- Closes the tab menu when the scoreboard key is released after being held for longer
-- than 0.3 seconds, unless the ShouldScoreboardHide hook returns false. A short press
-- leaves the menu open, and so does a menu that was opened from code.
function GM:ScoreboardHide()
  --- Asks whether the tab menu may close. Called on the client when the scoreboard key is
  -- released.
  -- @return [Boolean Return false to keep the tab menu open]
  if hook.Run('ShouldScoreboardHide') != false then
    local menu = Flux.TabMenu:get_panel()

    if menu and menu.held_time and CurTime() >= menu.held_time then
      Flux.TabMenu:close()
    end
  end
end

--- Adds the scoreboard and help items to the tab menu.
-- @param menu [Panel the fl_tab_menu being built]
function GM:AddTabMenuItems(menu)
  menu:add_menu_item('scoreboard', {
    title = t'ui.tab_menu.scoreboard',
    panel = 'fl_scoreboard',
    icon = 'fa-users',
    priority = 20
  })

  menu:add_menu_item('help', {
    title = t'ui.tab_menu.help',
    icon = 'fa-info-circle',
    panel = 'fl_help',
    priority = 50
  })
end

--- Adds the options that the scoreboard offers for every player to the menu of a player
-- card: opening their Steam profile and copying their SteamID. Bots have neither.
-- @param menu [Panel the DermaMenu being filled]
-- @param target [Player the player the card shows]
-- @param _card [Panel the fl_scoreboard_player card that was clicked]
function GM:CreateScoreboardPlayerMenu(menu, target, _card)
  if target:IsBot() then return end

  menu:AddOption(t'ui.scoreboard.menu.profile', function()
    if IsValid(target) then
      target:ShowProfile()
    end
  end):SetIcon('icon16/user.png')

  menu:AddOption(t'ui.scoreboard.menu.copy_steam_id', function()
    if IsValid(target) then
      SetClipboardText(target:SteamID())
    end
  end):SetIcon('icon16/page_copy.png')
end

--- Centers a newly opened panel within the tab menu.
-- @param menu_panel [Panel the tab menu]
-- @param active_panel [Panel the panel that has been opened]
function GM:OnMenuPanelOpen(menu_panel, active_panel)
  active_panel:SetPos(
    menu_panel:GetWide() * 0.5 - active_panel:GetWide() * 0.5,
    menu_panel:GetTall() * 0.5 - active_panel:GetTall() * 0.5
  )
end

--- Flashes the game window in the taskbar when the intro panel appears.
function GM:OnIntroPanelCreated()
  system.FlashWindow()
end
