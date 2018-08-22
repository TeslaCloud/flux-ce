--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]function flFactions:CharPanelCreated(id, panel)
  if (id == "CharCreation_General") then
    local factionTable
    local charData = panel:GetParent().CharData

    if (charData and charData.faction) then
      factionTable = faction.FindByID(charData.faction)
    end

    if (factionTable and !factionTable.HasName) then
      panel.NameLabel:SetVisible(false)
      panel.NameEntry:SetVisible(false)

      panel.DescLabel:SetPos(32, 64 - panel.NameLabel:GetTall())
      panel.DescEntry:SetPos(32, 66)
    end

    if (factionTable and !factionTable.HasDescription) then
      panel.DescLabel:SetVisible(false)
      panel.DescEntry:SetVisible(false)
    end

    if (factionTable and !factionTable.HasGender) then
      panel.GenderLabel:SetVisible(false)
      panel.GenderChooser:SetVisible(false)
    end
  end
end

function flFactions:OnThemeLoaded(activeTheme)
  activeTheme:AddPanel("CharCreation_Faction", function(id, parent, ...)
    return vgui.Create("flCharCreationFaction", parent)
  end)
end

function flFactions:AddCharacterCreationMenuItems(panel, menu, sidebar)
  menu:AddButton("Faction", function(btn)
    panel:OpenPanel("CharCreation_Faction")
  end)
end

function flFactions:PreRebuildScoreboard(panel, w, h)
  for k, v in ipairs(panel.playerCards) do
    if (IsValid(v)) then
      v:SafeRemove()
    end

    panel.playerCards[k] = nil
  end

  panel.factionCategories = panel.factionCategories or {}

  for k, v in ipairs(panel.factionCategories) do
    if (IsValid(v)) then
      v:SafeRemove()
    end

    panel.factionCategories[k] = nil
  end

  local curY = font.Scale(40)
  local cardTall = font.Scale(32) + 8
  local margin = font.Scale(4)

  local catList = vgui.Create("DListLayout", panel.scrollPanel)
  catList:SetSize(w - 8, h - 36)
  catList:SetPos(4, 36)

  for id, factionTable in pairs(faction.GetAll()) do
    local players = faction.GetPlayers(id)

    if (#players == 0) then continue end

    local cat = vgui.Create("DCollapsibleCategory", panel)
    cat:SetSize(w - 8, 32)
    cat:SetPos(4, curY)
    cat:SetLabel(factionTable.Name or id)

    catList:Add(cat)

    local list = vgui.Create("DPanelList", panel)
    list:SetSpacing(5)
    list:EnableHorizontal(false)

    cat:SetContents(list)

    for k, v in ipairs(players) do
      local playerCard = vgui.Create("flScoreboardPlayer", self)
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
