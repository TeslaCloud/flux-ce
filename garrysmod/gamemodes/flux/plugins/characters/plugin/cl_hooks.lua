--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]function flCharacters:PlayerInitialized()
  if (!fl.client:GetCharacter()) then
    if (!IsValid(fl.IntroPanel)) then
      fl.IntroPanel = vgui.Create("flIntro")

      if (IsValid(fl.IntroPanel)) then
        fl.IntroPanel:MakePopup()
      end
    end
  end
end

function flCharacters:OnIntroPanelRemoved()
  if (!fl.client:GetCharacter()) then
    fl.IntroPanel = theme.CreatePanel("MainMenu")

    if (IsValid(fl.IntroPanel)) then
      fl.IntroPanel:MakePopup()
    else
      timer.Create("flCreateMainPanel", 0.1, 0, function()
        fl.IntroPanel = theme.CreatePanel("MainMenu")

        if (IsValid(fl.IntroPanel)) then
          fl.IntroPanel:MakePopup()

          timer.Remove("flCreateMainPanel")
        end
      end)
    end
  end
end

do
  local curVolume = 1

  function flCharacters:Tick()
    if (fl.menuMusic) then
      if (!system.HasFocus()) then
        fl.menuMusic:SetVolume(0)
      else
        fl.menuMusic:SetVolume(curVolume)
      end

      if (!IsValid(fl.IntroPanel)) then
        if (curVolume > 0.05) then
          curVolume = Lerp(0.1, curVolume, 0)
          fl.menuMusic:SetVolume(curVolume)
        else
          curVolume = 1
          fl.menuMusic:Stop()
          fl.menuMusic = nil
        end
      end
    end
  end
end

function flCharacters:OnThemeLoaded(activeTheme)
  activeTheme:AddPanel("MainMenu", function(id, parent, ...)
    return vgui.Create("flMainMenu", parent)
  end)

  activeTheme:AddPanel("CharacterCreation", function(id, parent, ...)
    return vgui.Create("flCharacterCreation", parent)
  end)

  activeTheme:AddPanel("CharCreation_General", function(id, parent, ...)
    return vgui.Create("flCharCreationGeneral", parent)
  end)

  activeTheme:AddPanel("CharCreation_Model", function(id, parent, ...)
    return vgui.Create("flCharCreationModel", parent)
  end)

  if (IsValid(fl.IntroPanel)) then
    fl.IntroPanel:Remove()

    fl.IntroPanel = theme.CreatePanel("MainMenu")
    fl.IntroPanel:MakePopup()
  end
end

function flCharacters:AddTabMenuItems(menu)
  menu:AddMenuItem("mainmenu", {
    title = "Main Menu",
    icon = "fa-users",
    override = function(menuPanel, button)
      menuPanel:SafeRemove()
      fl.IntroPanel = theme.CreatePanel("MainMenu")
    end
  }, 1)
end

function flCharacters:PostCharacterLoaded(nCharID)
  if (IsValid(fl.IntroPanel)) then
    fl.IntroPanel:SafeRemove()
  end
end

function flCharacters:ShouldDrawLoadingScreen()
  if (!fl.IntroPanel) then
    return true
  end
end

function flCharacters:ShouldHUDPaint()
  return fl.client:CharacterLoaded()
end

function flCharacters:ShouldScoreboardHide()
  return fl.client:CharacterLoaded()
end

function flCharacters:ShouldScoreboardShow()
  return fl.client:CharacterLoaded()
end

function flCharacters:RebuildScoreboardPlayerCard(card, player)
  local x, y = card.nameLabel:GetPos()
  local oldX = x

  x = x + font.Scale(32) + 4

  card.nameLabel:SetPos(x, 2)

  if (IsValid(card.descLabel)) then
    card.descLabel:SafeRemove()
    card.spawnIcon:SafeRemove()
  end

  card.spawnIcon = vgui.Create("SpawnIcon", card)
  card.spawnIcon:SetPos(oldX - 4, 4)
  card.spawnIcon:SetSize(32, 32)
  card.spawnIcon:SetModel(player:GetModel())

  local physDesc = player:GetPhysDesc()

  if (physDesc:utf8len() > 64) then
    physDesc = physDesc:utf8sub(1, 64).."..."
  end

  card.descLabel = vgui.Create("DLabel", card)
  card.descLabel:SetText(physDesc)
  card.descLabel:SetFont(theme.GetFont("Text_Smaller"))
  card.descLabel:SetPos(x, card.nameLabel:GetTall())
  card.descLabel:SetTextColor(theme.GetColor("Text"))
  card.descLabel:SizeToContents()
end

function flCharacters:AddMainMenuItems(panel, sidebar)
  local scrW, scrH = ScrW(), ScrH()

  panel:AddButton("#MainMenu_New", function(btn)
    panel.menu = theme.CreatePanel("CharacterCreation", panel)

    if (panel.menu.AddSidebarItems) then
      panel:RecreateSidebar()
      panel.menu:AddSidebarItems(sidebar, panel)
    end
  end)

  local loadBtn = panel:AddButton("#MainMenu_Load", function(btn)
    panel.menu = vgui.Create("DFrame", panel)
    panel.menu:SetPos(scrW * 0.5 - 300, scrH / 4)
    panel.menu:SetSize(600, 600)
    panel.menu:SetTitle("LOAD CHARACTER")

    panel.menu.Paint = function(lp, w, h)
      draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
      draw.SimpleText("Which one to load", "DermaLarge", 0, 24)

      if (#fl.client:GetAllCharacters() <= 0) then
        draw.SimpleText("wow you have none", "DermaLarge", 0, 64)
      end
    end

    panel.menu:MakePopup()

    panel.menu.buttons = {}

    local offY = 0

    for k, v in ipairs(fl.client:GetAllCharacters()) do
      panel.menu.buttons[k] = vgui.Create("DButton", panel.menu)
      panel.menu.buttons[k]:SetPos(8, 100 + offY)
      panel.menu.buttons[k]:SetSize(128, 24)
      panel.menu.buttons[k]:SetText(v.name)
      panel.menu.buttons[k].DoClick = function()
        netstream.Start("PlayerSelectCharacter", v.id)
        panel:Remove()
      end

      offY = offY + 28
    end
  end)

  if (#fl.client:GetAllCharacters() <= 0) then
    loadBtn:SetEnabled(false)
  end

  if (fl.client:GetCharacter()) then
    panel:AddButton("#MainMenu_Cancel", function(btn)
      panel:Remove()
    end)
  else
    panel:AddButton("#MainMenu_Disconnect", function(btn)
      Derma_Query("#MainMenu_Disconnect_Msg", "#MainMenu_Disconnect", "#Yes", function()
        RunConsoleCommand("disconnect")
      end,
      "#No")
    end)
  end
end

netstream.Hook("PlayerCreatedCharacter", function(success, status)
  if (IsValid(fl.IntroPanel) and IsValid(fl.IntroPanel.menu)) then
    if (success) then
      fl.IntroPanel:RecreateSidebar(true)

      if (fl.IntroPanel.menu.Close) then
        fl.IntroPanel.menu:Close()
      else
        fl.IntroPanel.menu:SafeRemove()
      end
    else
      local text = "We were unable to create a character! (unknown error)"
      local hookText = hook.Run("GetCharCreationErrorText", success, status)

      if (hookText) then
        text = hookText
      elseif (status == CHAR_ERR_NAME) then
        text = "Your character's name must be between "..config.Get("character_min_name_len").." and "..config.Get("character_max_name_len").." characters long!"
      elseif (status == CHAR_ERR_DESC) then
        text = "Your character's description must be between "..config.Get("character_min_desc_len").." and "..config.Get("character_max_desc_len").." characters long!"
      elseif (status == CHAR_ERR_GENDER) then
        text = "You must pick a gender for your character before continuing!"
      elseif (status == CHAR_ERR_MODEL) then
        text = "You have not chosen a model or the one you have chosen is invalid!"
      end

      local panel = vgui.Create("flNotification", fl.IntroPanel)
      panel:SetText(text)
      panel:SetLifetime(6)
      panel:SetTextColor(Color("red"))
      panel:SetBackgroundColor(Color(50, 50, 50, 220))

      local w, h = panel:GetSize()
      panel:SetPos(ScrW() * 0.5 - w * 0.5, ScrH() - 128)

      function panel:PostThink() self:MoveToFront() end
    end
  end
end)
