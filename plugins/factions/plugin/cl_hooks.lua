function Factions:PreStageChange(id, panel)
  if id == 'char_create.general' then
    local gender = (panel.gender_female:is_active() and 'female') or (panel.gender_male:is_active() and 'male') or 'universal'
    local faction_id = panel:GetParent().char_data.faction
    local faction_table = Factions.find_by_id(faction_id)

    if gender == 'universal' and faction_table.has_gender then
      return false, t'ui.char_create.no_gender'
    end
  end
end

function Factions:OnThemeLoaded(current_theme)
  current_theme:add_panel('ui.char_create.faction', function(id, parent, ...)
    return vgui.Create('fl_char_create_faction', parent)
  end)
end

function Factions:AddCharacterCreationMenuStages(panel)
  panel:add_stage('ui.char_create.faction', 1)
end

function Factions:GetCharacterCreationModels(char_data)
  local faction_table = Factions.find_by_id(char_data.faction)

  return faction_table:get_gender_models(char_data.gender)
end

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

  hook.run('PreRebuildFactionCategories', players_table)

  for k, v in pairs(players_table) do
    local faction = (k == 'players_online' and t'ui.scoreboard.players_online') or Factions.find_by_id(k)
    local players = v

    if table.count(players) == 0 then continue end

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

function Factions:GetCharCreationErrorText(success, status)
  if status == CHAR_ERR_FACTION then
    return t'error.faction.not_selected'
  end
end
