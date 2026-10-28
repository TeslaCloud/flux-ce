--- Client side of the Factions plugin: adds the faction stage to character creation, adapts
-- the general stage to the chosen faction, explains why the server has refused a character
-- because of its faction, and groups the scoreboard by faction.

--- Hides the gender, description and name controls of the 'ui.char_create.general' stage
-- when the chosen faction does not have them. Factions without gender get the 'universal' one.
-- @param id [String ID of the stage that has just been opened]
-- @param panel [Panel the panel of that stage]
function Factions:CharPanelCreated(id, panel)
  if id == 'ui.char_create.general' then
    local faction_table
    local char_data = panel:GetParent().char_data

    if char_data and char_data.faction then
      faction_table = Factions.find_by_id(char_data.faction)
    end

    if faction_table then
      if !faction_table.has_gender then
        panel.gender_label:SetVisible(false)
        panel.gender_female:SetVisible(false)
        panel.gender_male:SetVisible(false)

        panel:GetParent().char_data.gender = 'universal'
        panel:rebuild_models()
      end

      if !faction_table.has_description then
        panel.desc_label:SetVisible(false)
        panel.desc_entry:SetVisible(false)
      end

      if !faction_table.has_name then
        panel.name_label:SetVisible(false)
        panel.name_entry:SetVisible(false)

        if IsValid(panel.name_random) then
          panel.name_random:SetVisible(false)
        end
      end
    end
  end
end

--- Stops the player from leaving the 'ui.char_create.general' stage without picking a gender
-- when the chosen faction requires one.
-- @param id [String ID of the stage being left]
-- @param panel [Panel the panel of that stage]
-- @return [Boolean false to block the change, String translated error; nothing otherwise]
function Factions:PreStageChange(id, panel)
  if id == 'ui.char_create.general' then
    local gender =
      (panel.gender_female:is_active() and 'female') or (panel.gender_male:is_active() and 'male') or 'universal'
    local faction_id = panel:GetParent().char_data.faction
    local faction_table = Factions.find_by_id(faction_id)

    if gender == 'universal' and faction_table.has_gender then
      return false, t'ui.char_create.no_gender'
    end
  end
end

--- Registers the faction selection panel with the theme.
-- @param current_theme [ThemeBase]
function Factions:OnThemeLoaded(current_theme)
  current_theme:add_panel('ui.char_create.faction', function(_id, parent, ...)
    return vgui.Create('fl_char_create_faction', parent)
  end)
end

--- Adds faction selection as the first stage of character creation.
-- @param panel [Panel the character creation menu]
function Factions:AddCharacterCreationMenuStages(panel)
  panel:add_stage('ui.char_create.faction', 1)
end

--- Returns the models of the chosen faction that match the chosen gender.
-- @param char_data [Map character data collected so far; needs faction and gender]
-- @return [List<String> model paths]
function Factions:GetCharacterCreationModels(char_data)
  local faction_table = Factions.find_by_id(char_data.faction)

  return faction_table:get_gender_models(char_data.gender)
end

--- Rebuilds the scoreboard with the players grouped into one collapsible category per
-- faction, replacing the default player list.
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

  panel.faction_categories = panel.faction_categories or {}

  for index, category_panel in ipairs(panel.faction_categories) do
    if IsValid(category_panel) then
      category_panel:safe_remove()
    end

    panel.faction_categories[index] = nil
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
  -- created. Called on the client each time the scoreboard is rebuilt.
  -- @param players_table [Map lists of players keyed by faction ID, with an entry for every
  --   faction that has players online; modify it in place. An entry under the 'players_online'
  --   key becomes a category titled with the 'ui.scoreboard.players_online' phrase; every
  --   other key has to be the ID of a registered faction]
  hook.Run('PreRebuildFactionCategories', players_table)

  for id, members in pairs(players_table) do
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

      local timer_name = 'ping_updater_'..client:SteamID()

      timer.Create(timer_name, 1, 0, function()
        if IsValid(player_card) and IsValid(client) then
          player_card.ping:SetText(client:Ping())
        else
          timer.Remove(timer_name)
        end
      end)

      card_list:AddItem(player_card)

      panel.player_cards[#panel.player_cards + 1] = player_card
    end

    cur_y = cur_y + category:GetTall() + card_tall + margin
  end

  return true
end

--- Supplies the error text shown when character creation fails because of the faction: no
-- faction was chosen, the player has too many characters of it, or the faction has refused
-- the character, in which case the reason the server has sent is shown if there is one.
-- @param _success [Boolean]
-- @param status [Number CHAR_* status code sent by the server]
-- @return [String translated error for the CHAR_ERR_FACTION codes, otherwise nil]
function Factions:GetCharCreationErrorText(_success, status)
  local refusal = self.creation_refusal

  self.creation_refusal = nil

  if status == CHAR_ERR_FACTION then
    return t'error.faction.not_selected'
  elseif status == CHAR_ERR_FACTION_LIMIT then
    return t'ui.char_create.faction_limit'
  elseif status == CHAR_ERR_FACTION_REFUSED then
    return refusal or t'error.faction.creation_refused'
  end
end
