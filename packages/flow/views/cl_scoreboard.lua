--- The scoreboard of the tab menu: `fl_scoreboard`, the list of players, and
-- `fl_scoreboard_player`, the card of a single player.
-- Plugins change its contents through the `PreRebuildScoreboard`, `RebuildScoreboard` and
-- `RebuildScoreboardPlayerCard` hooks.

--- The scoreboard page of the tab menu (`fl_scoreboard`): a scrollable list with one
-- `fl_scoreboard_player` card per initialized player, drawn by the active theme's
-- `PaintScoreboard` hook.
-- `rebuild` recreates the cards. A `PreRebuildScoreboard` handler can build the list itself,
-- which is how the Factions plugin groups the players by faction, and `RebuildScoreboard`
-- handlers can add to the default list.
local PANEL = {}
PANEL.player_cards = {}

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

--- Removes the existing player cards and creates one for every initialized player, then
-- runs the RebuildScoreboard hook. Does nothing if PreRebuildScoreboard returns a value.
function PANEL:rebuild()
  local w, h = self:GetSize()

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

  local cur_y = math.scale(40)
  local card_tall = math.scale(32) + math.scale(8)
  local margin = math.scale(2)

  for k, v in player.Iterator() do
    if !v:has_initialized() then continue end

    local player_card = vgui.Create('fl_scoreboard_player', self)
    player_card:SetSize(w - 8, card_tall)
    player_card:SetPos(4, cur_y)
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
-- elements in the `RebuildScoreboardPlayerCard` hook.
local PANEL = {}
PANEL.player = false

--- Draws the background of the player card.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background_light'))
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

  self.avatar_panel = vgui.Create('fl_avatar_panel', self)
  self.avatar_panel:SetSize(math.scale_size(32, 32))
  self.avatar_panel:SetPos(math.scale_size(4, 4))
  self.avatar_panel:set_player(target, 64)

  local text = target:name()
  local font = Theme.get_font('text_normal')
  local text_w, text_h = util.text_size(text, font)

  self.name_label = vgui.Create('DLabel', self)
  self.name_label:SetText(text)
  self.name_label:SetPos(math.scale(48), math.scale(4))
  self.name_label:SetFont(font)
  self.name_label:SetTextColor(Theme.get_color('text'))
  self.name_label:SizeToContents()

  text = target:Ping()
  text_w, text_h = util.text_size(text, font)

  self.ping = vgui.Create('DLabel', self)
  self.ping:SetText(text)
  self.ping:SetPos(self:GetWide() - text_w - math.scale(16), self:GetTall() * 0.5 - text_h * 0.5)
  self.ping:SetFont(font)
  self.ping:SetTextColor(Theme.get_color('text'))
  self.ping:SizeToContents()

  --- Called on the client after a scoreboard player card has created its avatar, name and ping
  -- labels (the `avatar_panel`, `name_label` and `ping` fields of the card), so that plugins
  -- can add to the card or rearrange it.
  -- @param card [Panel The `fl_scoreboard_player` card]
  -- @param target [Player The player the card shows]
  hook.Run('RebuildScoreboardPlayerCard', self, target)
end

vgui.Register('fl_scoreboard_player', PANEL, 'fl_base_panel')
