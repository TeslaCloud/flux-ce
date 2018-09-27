function flFactions:CharPanelCreated(id, panel)
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

function flFactions:PreStageChange(id, panel)
  if id == 'char_create.general' then
    local gender = (panel.gender_female:IsActive() and 'Female') or (panel.gender_male:IsActive() and 'Male') or 'Universal'
    local faction_id = panel:GetParent().char_data.faction
    local faction_table = faction.find_by_id(faction_id)

    if gender == 'Universal' and faction_table.has_gender then
      return false, t('char_creation.no_gender')
    end
  end
end

function flFactions:OnThemeLoaded(current_theme)
  current_theme:add_panel('CharCreation_Faction', function(id, parent, ...)
    return vgui.Create('flCharCreationFaction', parent)
  end)
end

function flFactions:AddCharacterCreationMenuStages(panel)
  panel:add_stage('CharCreation_Faction', 1)
end

function flFactions:PreRebuildScoreboard(panel, w, h)
  for k, v in ipairs(panel.playerCards) do
    if IsValid(v) then
      v:SafeRemove()
    end

    panel.playerCards[k] = nil
  end

  panel.factionCategories = panel.factionCategories or {}

  for k, v in ipairs(panel.factionCategories) do
    if IsValid(v) then
      v:SafeRemove()
    end

    panel.factionCategories[k] = nil
  end

  local curY = font.Scale(40)
  local cardTall = font.Scale(32) + 8
  local margin = font.Scale(4)

  local catList = vgui.Create('DListLayout', panel.scrollPanel)
  catList:SetSize(w - 8, h - 36)
  catList:SetPos(4, 36)

  for id, faction_table in pairs(faction.GetAll()) do
    local players = faction.GetPlayers(id)

    if #players == 0 then continue end

    local cat = vgui.Create('DCollapsibleCategory', panel)
    cat:SetSize(w - 8, 32)
    cat:SetPos(4, curY)
    cat:SetLabel(faction_table.name or id)

    catList:Add(cat)

    local list = vgui.Create('DPanelList', panel)
    list:SetSpacing(5)
    list:EnableHorizontal(false)

    cat:SetContents(list)

    for k, v in ipairs(players) do
      local playerCard = vgui.Create('fl_scoreboard_player', self)
      playerCard:SetSize(w - 8, cardTall)
      playerCard:SetPlayer(v)
      playerCard:SetPos(0, 5)

      list:AddItem(playerCard)

      table.insert(panel.playerCards, playerCard)
    end

    curY = curY + cat:GetTall() + cardTall + margin
  end

  return true
end
