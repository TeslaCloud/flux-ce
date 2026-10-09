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
  current_theme:add_panel('ui.char_create.faction', function(id, parent, ...)
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
  for k, v in ipairs(panel.player_cards) do
    if IsValid(v) then
      v:safe_remove()
    end

    panel.player_cards[k] = nil
  end

  panel.faction_categories = panel.faction_categories or {}

  for k, v in ipairs(panel.faction_categories) do
    if IsValid(v) then
      v:safe_remove()
    end

    panel.faction_categories[k] = nil
  end

  local cur_y = math.scale(40)
  local card_tall = math.scale(40)
  local margin = math.scale(2)

  local category_list = vgui.Create('DListLayout', panel.scroll_panel)
  category_list:SetSize(w - 8, h - math.scale(20))
  category_list:SetPos(4, math.scale(20))

  local players_table = {}

  for k, v in pairs(Factions.all()) do
    local players = Factions.get_players(k)

    if #players == 0 then continue end

    players_table[k] = players
  end

  --- Lets plugins regroup the players of the scoreboard before its faction categories are
  -- created. Called on the client each time the scoreboard is rebuilt.
  -- @param players_table [Map lists of players keyed by faction ID, with an entry for every
  --   faction that has players online; modify it in place. An entry under the 'players_online'
  --   key becomes a category titled with the 'ui.scoreboard.players_online' phrase; every
  --   other key has to be the ID of a registered faction]
  hook.Run('PreRebuildFactionCategories', players_table)

  for k, v in pairs(players_table) do
    local faction = (k == 'players_online' and t'ui.scoreboard.players_online') or Factions.find_by_id(k)
    local players = v

    if table.Count(players) == 0 then continue end

    local category = vgui.Create('DCollapsibleCategory', panel)
    category:SetSize(w - 8, 32)
    category:SetPos(4, cur_y)
    category:SetLabel(isstring(faction) and faction or t(faction.name) or k)

    category_list:Add(category)

    local list = vgui.Create('DPanelList', panel)
    list:SetSpacing(math.scale(2))
    list:EnableHorizontal(false)

    category:SetContents(list)

    for k1, v1 in pairs(players) do
      if !IsValid(v1) then continue end

      local player_card = vgui.Create('fl_scoreboard_player', category)
      player_card:SetSize(w - 8, card_tall)
      player_card:set_player(v1)
      player_card:SetPos(0, 5)

      local timer_name = 'ping_updater_'..v1:SteamID()

      timer.Create(timer_name, 1, 0, function()
        if IsValid(player_card) and IsValid(v1) then
          player_card.ping:SetText(v1:Ping())
        else
          timer.Remove(timer_name)
        end
      end)

      list:AddItem(player_card)

      table.insert(panel.player_cards, player_card)
    end

    cur_y = cur_y + category:GetTall() + card_tall + margin
  end

  return true
end

--- Supplies the error text shown when character creation fails because of the faction: no
-- faction was chosen, the player has too many characters of it, or the faction has refused
-- the character, in which case the reason the server has sent is shown if there is one.
-- @param success [Boolean]
-- @param status [Number CHAR_* status code sent by the server]
-- @return [String translated error for the CHAR_ERR_FACTION codes, otherwise nil]
function Factions:GetCharCreationErrorText(success, status)
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

Cable.receive('fl_faction_creation_refused', function(reason, arguments)
  if isstring(reason) then
    Factions.creation_refusal = t(reason, arguments)
  end
end)
