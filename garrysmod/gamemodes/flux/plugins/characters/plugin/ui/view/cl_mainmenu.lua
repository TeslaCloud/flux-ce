local PANEL = {}
PANEL.prevButton = nil

function PANEL:Init()
  self:SetPos(0, 0)
  self:SetSize(ScrW(), ScrH())

  self:RecreateSidebar(true)

  self:MakePopup()

  local menuMusic = theme.GetOption("MenuMusic")

  if (!fl.menuMusic and menuMusic and menuMusic != "") then
    sound.PlayFile(menuMusic, "", function(station)
      if (IsValid(station)) then
        station:Play()

        fl.menuMusic = station
      end
    end)
  end

  theme.Hook("CreateMainMenu", self)
end

function PANEL:Paint(w, h)
  theme.Hook("PaintMainMenu", self, w, h)
end

function PANEL:Think() end

function PANEL:RecreateSidebar(bShouldCreateButtons)
  if (IsValid(self.sidebar)) then
    self.sidebar:SafeRemove()
  end

  -- Hot Fix for an error that occurred when auto-reloading while in initial main menu.
  if (!theme.GetOption("MainMenu_SidebarLogo")) then
    timer.Simple(0.05, function() self:RecreateSidebar(true) end)

    return
  end

  self.sidebar = vgui.Create("flSidebar", self)
  self.sidebar:SetPos(theme.GetOption("MainMenu_SidebarX"), theme.GetOption("MainMenu_SidebarY"))
  self.sidebar:SetSize(theme.GetOption("MainMenu_SidebarWidth"), theme.GetOption("MainMenu_SidebarHeight"))
  self.sidebar:SetMargin(theme.GetOption("MainMenu_SidebarMargin"))
  self.sidebar:AddSpace(16)

  self.sidebar.Paint = function() end

  self.sidebar:AddSpace(theme.GetOption("MainMenu_SidebarLogoSpace"))

  if (bShouldCreateButtons) then
    hook.Run("AddMainMenuItems", self, self.sidebar)
  else
    local backButton = vgui.Create("flButton")
    backButton:SetSize(theme.GetOption("MainMenu_SidebarWidth"), theme.GetOption("MainMenu_SidebarButtonHeight"))
    backButton:SetIcon("fa-chevron-left")
    backButton:SetIconSize(16)
    backButton:SetFont(theme.GetFont("Text_NormalSmaller"))
    backButton:SetTitle("#CharCreate_Back")

    backButton.DoClick = function(btn)
      self:RecreateSidebar(true)

      if (self.menu.Close) then
        self.menu:Close()
      else
        self.menu:SafeRemove()
      end
    end

    self.sidebar:AddPanel(backButton)
    self.sidebar:AddSpace(9)
  end
end

function PANEL:OpenMenu(panel, data)
  if (!IsValid(self.menu)) then
    self.menu = theme.CreatePanel(panel, self)

    if (self.menu.set_data) then
      self.menu:set_data(data)
    end
  else
    if (self.menu.Close) then
      self.menu:Close(function()
        self:OpenMenu(panel, data)
      end)
    else
      self.menu:SafeRemove()
      self:OpenMenu(panel, data)
    end
  end
end

function PANEL:add_button(text, callback)
  local button = vgui.Create("flButton", self)
  button:SetSize(theme.GetOption("MainMenu_SidebarWidth"), theme.GetOption("MainMenu_SidebarButtonHeight"))
  button:SetText(string.utf8upper(L(text)))
  button:SetDrawBackground(false)
  button:SetFont(theme.GetFont("Menu_Larger"))
  button:SetPos(16, 0)
  button:SetTextAutoposition(false)
  button:SetTextOffset(8)

  button.DoClick = function(btn)
    btn:SetActive(true)

    if (IsValid(self.prevButton) and self.prevButton != btn) then
      self.prevButton:SetActive(false)
    end

    self.prevButton = btn

    if (isfunction(callback)) then
      callback(btn)
    elseif (isstring(callback)) then
      self:OpenMenu(callback)
    end
  end

  self.sidebar:AddPanel(button)
  self.sidebar:AddSpace(6)

  return button
end

vgui.register("flMainMenu", PANEL, "EditablePanel")
