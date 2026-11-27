--- Client side of the Factions plugin: explains why the server has refused a character
-- because of the faction it would start in, and groups the scoreboard by faction.

--- Returns where the category of a faction goes on the scoreboard: the team ID of the
-- faction, which follows the order in which the factions were registered. Categories that
-- are not factions, such as the players online, go last.
-- @param id [String faction ID or category key]
-- @return [Number]
local function category_order(id)
  return Factions.find_by_id(id)?.team_id or math.huge
end

--- Takes the players that the scoreboard does not list (see `fl_scoreboard:should_show_player`)
-- out of the lists of players that the faction categories are built from.
local function remove_hidden_players(panel, players_table)
  for _, members in pairs(players_table) do
    for key, client in pairs(members) do
      if !panel:should_show_player(client) then
        members[key] = nil
      end
    end
  end
end

--- Rebuilds the scoreboard with the players grouped into one collapsible category per
-- faction, ordered by the team IDs of the factions with the players online last, replacing
-- the default player list.
-- @param panel [Panel the scoreboard]
-- @param w [Number]
-- @param h [Number]
-- @return [Boolean always true, which stops the default rebuild]
function Factions:PreRebuildScoreboard(panel, w, h)
  for index, card in ipairs(panel.player_cards) do
    if IsValid(card) then
      card:safe_remove()
    end

    panel.player_cards[index] = nil
  end

  local padding = math.scale(12)
  local cur_y = math.scale(44)
  local card_tall = math.scale(44)
  local margin = math.scale(4)

  local category_list = vgui.Create('DListLayout', panel.scroll_panel)
  category_list:SetSize(w - padding * 2, h - cur_y - padding)
  category_list:SetPos(padding, cur_y)

  local players_table = {}

  for _, client in player.Iterator() do
    local faction_id = client:get_faction_id()

    if Factions.find_by_id(faction_id) then
      local players = players_table[faction_id]

      if !players then
        players = {}
        players_table[faction_id] = players
      end

      players[#players + 1] = client
    end
  end

  --- Lets plugins regroup the players of the scoreboard before its faction categories are
  -- created. Called on the client each time the scoreboard is rebuilt. The players that are
  -- kept off the scoreboard are taken out of the lists afterward, wherever the handlers have
  -- put them.
  -- @param players_table [Map lists of players keyed by faction ID, with an entry for every
  --   faction that has players online; modify it in place. An entry under the 'players_online'
  --   key becomes a category titled with the 'ui.scoreboard.players_online' phrase; every
  --   other key has to be the ID of a registered faction]
  hook.Run('PreRebuildFactionCategories', players_table)

  remove_hidden_players(panel, players_table)

  local category_ids = table.GetKeys(players_table)

  table.sort(category_ids, |a, b| -> category_order(a) < category_order(b))

  for _, id in ipairs(category_ids) do
    local members = players_table[id]
    local faction = (id == 'players_online' and t'ui.scoreboard.players_online') or Factions.find_by_id(id)

    if table.Count(members) == 0 then continue end

    local category = vgui.Create('DCollapsibleCategory', panel)
    category:SetSize(w - padding * 2, 32)
    category:SetPos(padding, cur_y)
    category:SetLabel(isstring(faction) and faction or t(faction.name) or id)
    category:DockMargin(0, 0, 0, math.scale(6))
    category:DockPadding(margin, margin, margin, margin)

    category_list:Add(category)

    local card_list = vgui.Create('DPanelList', panel)
    card_list:SetSpacing(margin)
    card_list:SetPadding(margin)
    card_list:EnableHorizontal(false)

    category:SetContents(card_list)

    for _, client in pairs(members) do
      if !IsValid(client) then continue end

      local player_card = vgui.Create('fl_scoreboard_player', category)
      player_card:SetSize(w - padding * 2 - margin * 4, card_tall)
      player_card:set_player(client)
      player_card:SetPos(0, 5)

      card_list:AddItem(player_card)

      panel.player_cards[#panel.player_cards + 1] = player_card
    end

    cur_y = cur_y + category:GetTall() + card_tall + margin
  end

  --- Called on the client after the faction categories of the scoreboard and their player
  -- cards have been created.
  -- @param players_table [Map lists of players keyed by faction ID or 'players_online', as
  --   the categories have been built from them]
  -- @param panel [Panel the scoreboard]
  hook.Run('PostRebuildFactionCategories', players_table, panel)

  return true
end

--- Supplies the error text shown when character creation fails because the faction the
-- character would start in has refused it: the reason the server has sent, if there is one.
-- @param _success [Boolean]
-- @param status [Number CHAR_* status code sent by the server]
-- @return [String translated error for CHAR_ERR_FACTION_REFUSED, otherwise nil]
function Factions:GetCharacterCreationErrorText(_success, status)
  local refusal = self.creation_refusal

  self.creation_refusal = nil

  if status == CHAR_ERR_FACTION_REFUSED then
    return refusal or t'error.faction.creation_refused'
  end
end
