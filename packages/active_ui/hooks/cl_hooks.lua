--- Client side of the interface hooks: the `GM` handlers that make Derma use the Flux skin,
-- create the fonts once the schema has loaded and again when the screen resolution changes,
-- open the tab menu in place of the scoreboard, fill the tab menu and the player menu of
-- the scoreboard, center the panels of the tab menu and flash the game window when the
-- intro appears.

local IsValid = IsValid
local CurTime = CurTime

--- Creates the fonts once the schema has been loaded on the client.
function GM:FluxClientSchemaLoaded()
  Font.create_fonts()
end

--- Makes Derma use the Flux skin by default.
-- @return [String name of the skin]
function GM:ForceDermaSkin()
  return 'Flux'
end

--- Recreates the fonts so that they fit the new resolution.
-- @param new_w [Number new screen width]
-- @param new_h [Number new screen height]
-- @param old_w [Number previous screen width]
-- @param old_h [Number previous screen height]
function GM:OnResolutionChanged(new_w, new_h, old_w, old_h)
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
-- @param card [Panel the fl_scoreboard_player card that was clicked]
function GM:CreateScoreboardPlayerMenu(menu, target, card)
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

--- Takes the players that are kept off the scoreboard out of the lists that the Factions
-- plugin builds its scoreboard categories from, so that PlayerShouldShowOnScoreboard also
-- applies when the players are grouped by faction. Handles the PreRebuildFactionCategories
-- hook of that plugin and runs after the plugins that regroup the players.
-- @param players_table [Map lists of players keyed by category]
function GM:PreRebuildFactionCategories(players_table)
  for id, players in pairs(players_table) do
    for k, v in pairs(players) do
      if IsValid(v) and v:has_initialized() and hook.Run('PlayerShouldShowOnScoreboard', v) == false then
        players[k] = nil
      end
    end
  end
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
