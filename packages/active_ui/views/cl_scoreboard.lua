--- The scoreboard of the tab menu: `fl_scoreboard`, the list of players, and
-- `fl_scoreboard_player`, the card of a single player.
-- Plugins change its contents through the `PreRebuildScoreboard`, `RebuildScoreboard` and
-- `RebuildScoreboardPlayerCard` hooks, keep players off it with
-- `PlayerShouldShowOnScoreboard` and add to the menu that a click on a player card opens
-- with `CreateScoreboardPlayerMenu`.

local IsValid = IsValid

--- The scoreboard page of the tab menu (`fl_scoreboard`): a scrollable list with one
-- `fl_scoreboard_player` card per initialized player, drawn by the active theme's
-- `PaintScoreboard` hook, which also writes how many players are online.
-- `rebuild` recreates the cards. A `PreRebuildScoreboard` handler can build the list itself,
-- which is how the Factions plugin groups the players by faction, and `RebuildScoreboard`
-- handlers can add to the default list. Either way a player is left out when a
-- `PlayerShouldShowOnScoreboard` handler returns false.
local PANEL = {}
PANEL.player_cards = {}
PANEL.online_count = 0

--- Creates the scroll panel that holds the player cards.
function PANEL:Init()
  self.scroll_panel = vgui.Create('DScrollPanel', self)
  self.scroll_panel:SetPos(0, 0)
  self.scroll_panel:SetSize(self:get_menu_size())
end

--- Delegates drawing of the scoreboard to the active theme's PaintScoreboard hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Theme.hook('PaintScoreboard', self, w, h)
end

--- Checks whether a player is listed on the scoreboard: they are once they have been
-- initialized, unless a PlayerShouldShowOnScoreboard handler returns false.
-- @param target [Player]
-- @return [Boolean]
function PANEL:should_show_player(target)
  if !IsValid(target) or !target:has_initialized() then return false end

  --- Asks whether a player is listed on the scoreboard. Called on the client for every
  -- initialized player each time the scoreboard is rebuilt, also when the Factions plugin
  -- groups the players by faction. A player who is kept off the scoreboard is not counted
  -- in its line of players online either.
  -- @param target [Player The player about to be listed]
  -- @return [Boolean Return false to keep the player off the scoreboard. Return nothing
  --   otherwise, so that the other handlers are asked as well]
  return hook.Run('PlayerShouldShowOnScoreboard', target) != false
end

--- Counts the players for the line of players online: everyone who is connected, including
-- those who are still loading, except for the players that are kept off the scoreboard.
-- @return [Number]
function PANEL:count_players()
  local count = 0

  for k, v in player.Iterator() do
    if !v:has_initialized() or self:should_show_player(v) then
      count = count + 1
    end
  end

  return count
end

--- Returns the text of the line of players online, as it was when the scoreboard was last
-- rebuilt. The theme draws it in its PaintScoreboard hook.
-- @return [String translated text, such as 'Players online: 12 / 32']
function PANEL:get_online_text()
  return (t('ui.scoreboard.online', { count = self.online_count, max = game.MaxPlayers() }))
end

--- Counts the players online, removes the existing player cards and creates one for every
-- player that is listed, then runs the RebuildScoreboard hook. Only the count is done if
-- PreRebuildScoreboard returns a value.
function PANEL:rebuild()
  local w, h = self:GetSize()

  self.online_count = self:count_players()

  --- Called on the client before the scoreboard builds its list of players.
  -- A handler can build the contents itself, for example to group the players.
  -- @param panel [Panel The `fl_scoreboard` being rebuilt]
  -- @param w [Number Width of the scoreboard]
  -- @param h [Number Height of the scoreboard]
  -- @return [Any Return anything but nil to skip the default player list and the
  --   `RebuildScoreboard` hook]
  if hook.Run('PreRebuildScoreboard', self, w, h) != nil then
    return
  end

  for k, v in ipairs(self.player_cards) do
    if IsValid(v) then
      v:safe_remove()
    end

    self.player_cards[k] = nil
  end

  local padding = math.scale(12)
  local cur_y = math.scale(44)
  local card_tall = math.scale(32) + math.scale(12)
  local margin = math.scale(4)

  for k, v in player.Iterator() do
    if !self:should_show_player(v) then continue end

    local player_card = vgui.Create('fl_scoreboard_player', self)
    player_card:SetSize(w - padding * 2, card_tall)
    player_card:SetPos(padding, cur_y)
    player_card:set_player(v)

    self.scroll_panel:AddItem(player_card)

    cur_y = cur_y + card_tall + margin

    table.insert(self.player_cards, player_card)
  end

  --- Called on the client after the scoreboard has created the default player cards.
  -- Not called when a `PreRebuildScoreboard` handler has built the list instead.
  -- @param panel [Panel The `fl_scoreboard` that has been rebuilt]
  -- @param w [Number Width of the scoreboard]
  -- @param h [Number Height of the scoreboard]
  hook.Run('RebuildScoreboard', self, w, h)
end

--- Returns the size the tab menu gives this panel when it opens it.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math.scale(1280), math.scale(800)
end

vgui.Register('fl_scoreboard', PANEL, 'fl_base_panel')

--- The card of one player on the scoreboard (`fl_scoreboard_player`): their avatar, name and
-- ping.
-- Assign the player with `set_player`, which also builds the card. Plugins add their own
-- elements in the `RebuildScoreboardPlayerCard` hook. A click on the card opens a menu of
-- things to do with the player (`open_menu`), which plugins fill in the
-- `CreateScoreboardPlayerMenu` hook.
local PANEL = {}
PANEL.player = false

--- Opens the menu of the card's player when the card is clicked with the left or the right
-- mouse button. Children of the card that take clicks themselves, such as the avatar, keep
-- their own behaviour.
-- @param code [Number mouse button code, one of the MOUSE_ enums]
function PANEL:OnMousePressed(code)
  if code == MOUSE_LEFT or code == MOUSE_RIGHT then
    self:open_menu()
  end
end

--- Builds the menu of things to do with the card's player through the
-- CreateScoreboardPlayerMenu hook and opens it at the cursor. No menu is shown if no
-- handler has added an option.
-- @return [Panel the opened DermaMenu, or nil if there is nothing to show]
function PANEL:open_menu()
  local target = self.player

  if !IsValid(target) then return end

  local menu = DermaMenu()

  --- Called on the client when a player card of the scoreboard is clicked, to fill the menu
  -- of things to do with that player. The menu opens at the cursor if a handler has added
  -- anything to it and is removed otherwise. The gamemode's handler, which runs last,
  -- adds the options to open the Steam profile of the player and to copy their SteamID.
  -- An option that does something on the server still has to be checked there: sending a
  -- command with `Flux.Command:send` takes care of that.
  -- ```
  -- function MyPlugin:CreateScoreboardPlayerMenu(menu, target, card)
  --   if target != PLAYER and PLAYER:can('poke') then
  --     menu:AddOption(t'ui.my_plugin.poke', function()
  --       Flux.Command:send('poke "'..target:name()..'"')
  --     end):SetIcon('icon16/user_comment.png')
  --   end
  -- end
  -- ```
  -- @param menu [Panel The `DermaMenu` to add options to]
  -- @param target [Player The player the card shows]
  -- @param card [Panel The `fl_scoreboard_player` card that was clicked]
  -- @return [Any Return nothing, so that the other handlers can add their options as well]
  hook.Run('CreateScoreboardPlayerMenu', menu, target, self)

  if menu:ChildCount() > 0 then
    menu:Open()

    return menu
  end

  menu:safe_remove()
end

--- Draws the background of the player card through the theme's PaintScoreboardPlayer hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Theme.hook('PaintScoreboardPlayer', self, w, h)
end

--- Sets the player this card represents and rebuilds the card.
-- @param target [Player]
function PANEL:set_player(target)
  self.player = target

  self:rebuild()
end

--- Recreates the avatar, name and ping labels for the card's player and runs the
-- RebuildScoreboardPlayerCard hook. Does nothing if no player is set.
function PANEL:rebuild()
  if !self.player then return end

  if IsValid(self.avatar_panel) then
    self.avatar_panel:safe_remove()
    self.name_label:safe_remove()
  end

  local target = self.player

  local padding = math.scale(6)
  local avatar_size = math.scale(32)

  self.avatar_panel = vgui.Create('fl_avatar_panel', self)
  self.avatar_panel:SetSize(avatar_size, avatar_size)
  self.avatar_panel:SetPos(padding, self:GetTall() * 0.5 - avatar_size * 0.5)
  self.avatar_panel:set_player(target, 64)

  local text = target:name()
  local font = Theme.get_font('text_normal')
  local text_w, text_h = util.text_size(text, font)

  self.name_label = vgui.Create('DLabel', self)
  self.name_label:SetText(text)
  self.name_label:SetPos(padding * 2 + avatar_size, math.scale(4))
  self.name_label:SetFont(font)
  self.name_label:SetTextColor(Theme.get_color('text'))
  self.name_label:SizeToContents()

  text = target:Ping()
  text_w, text_h = util.text_size(text, font)

  self.ping = vgui.Create('DLabel', self)
  self.ping:SetText(text)
  self.ping:SetPos(self:GetWide() - text_w - math.scale(16), self:GetTall() * 0.5 - text_h * 0.5)
  self.ping:SetFont(font)
  self.ping:SetTextColor(Theme.get_color('text_muted'))
  self.ping:SizeToContents()

  --- Called on the client after a scoreboard player card has created its avatar, name and ping
  -- labels (the `avatar_panel`, `name_label` and `ping` fields of the card), so that plugins
  -- can add to the card or rearrange it.
  -- @param card [Panel The `fl_scoreboard_player` card]
  -- @param target [Player The player the card shows]
  hook.Run('RebuildScoreboardPlayerCard', self, target)
end

vgui.Register('fl_scoreboard_player', PANEL, 'fl_base_panel')
