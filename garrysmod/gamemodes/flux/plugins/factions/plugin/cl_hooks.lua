function Factions:CharPanelCreated(id, panel)
  if id == 'char_create.general' then
    local faction_table
    local char_data = panel:GetParent().char_data

    if char_data and char_data.faction then
      faction_table = faction.find_by_id(char_data.faction)
    end

    if faction_table and !faction_table.has_name then
      panel.name_label:SetVisible(false)
      panel.name_entry:SetVisible(false)
      panel.name_random:SetVisible(false)
    end

    if faction_table and !faction_table.has_description then
      panel.desc_label:SetVisible(false)
      panel.desc_entry:SetVisible(false)
    end

    if faction_table and !faction_table.has_gender then
      panel.gender_label:SetVisible(false)
      panel.gender_male:SetVisible(false)
      panel.gender_female:SetVisible(false)
    end
  end
end

function Factions:PreStageChange(id, panel)
  if id == 'char_create.general' then
    local gender = (panel.gender_female:is_active() and 'Female') or (panel.gender_male:is_active() and 'Male') or 'Universal'
    local faction_id = panel:GetParent().char_data.faction
    local faction_table = faction.find_by_id(faction_id)

    if gender == 'Universal' and faction_table.has_gender then
      return false, t'char_creation.no_gender'
    end
  end
end

function Factions:OnThemeLoaded(current_theme)
  current_theme:add_panel('CharCreation_Faction', function(id, parent, ...)
    return vgui.Create('flCharCreationFaction', parent)
  end)
end

function Factions:AddCharacterCreationMenuStages(panel)
  panel:add_stage('CharCreation_Faction', 1)
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

  local cur_y = font.scale(40)
  local card_tall = font.scale(32) + 8
  local margin = font.scale(4)

  local category_list = vgui.Create('DListLayout', panel.scroll_panel)
  category_list:SetSize(w - 8, h - 36)
  category_list:SetPos(4, 36)

  for k, v in pairs(faction.all()) do
    local players = faction.get_players(k)

    if #players == 0 then continue end

    local category = vgui.Create('DCollapsibleCategory', panel)
    category:SetSize(w - 8, 32)
    category:SetPos(4, cur_y)
    category:SetLabel(v.name or k)

    category_list:Add(category)

    local list = vgui.Create('DPanelList', panel)
    list:SetSpacing(5)
    list:EnableHorizontal(false)

    category:SetContents(list)

    for k1, v1 in ipairs(players) do
      local player_card = vgui.Create('fl_scoreboard_player', self)
      player_card:SetSize(w - 8, card_tall)
      player_card:set_player(v1)
      player_card:SetPos(0, 5)

      list:AddItem(player_card)

      table.insert(panel.player_cards, player_card)
    end

    cur_y = cur_y + category:GetTall() + card_tall + margin
  end

  return true
end
