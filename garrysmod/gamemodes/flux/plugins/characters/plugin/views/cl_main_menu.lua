local PANEL = {}
PANEL.prevButton = nil

function PANEL:Init()
  self:SetPos(0, 0)
  self:SetSize(ScrW(), ScrH())

  self:RecreateSidebar(true)

  self:MakePopup()

  local menuMusic = theme.GetOption('MenuMusic')

  if !fl.menuMusic and menuMusic and menuMusic != '' then
    sound.PlayFile(menuMusic, '', function(station)
      if IsValid(station) then
        station:Play()

        fl.menuMusic = station
      end
    end)
  end

  theme.Hook('CreateMainMenu', self)
end

function PANEL:Paint(w, h)
  if self:IsVisible() then
    theme.Hook('PaintMainMenu', self, w, h)
  end
end

function PANEL:Think() end

function PANEL:RecreateSidebar(bShouldCreateButtons)
  if IsValid(self.sidebar) then
    self.sidebar:SafeRemove()
  end

  self.sidebar = vgui.Create('fl_sidebar', self)
  self.sidebar:SetPos(theme.GetOption('MainMenu_SidebarX'), theme.GetOption('MainMenu_SidebarY'))
  self.sidebar:SetSize(theme.GetOption('MainMenu_SidebarWidth'), theme.GetOption('MainMenu_SidebarHeight'))
  self.sidebar:SetMargin(theme.GetOption('MainMenu_SidebarMargin'))
  self.sidebar:AddSpace(16)

  self.sidebar.Paint = function() end

  self.sidebar:AddSpace(theme.GetOption('MainMenu_SidebarLogoSpace'))

  if bShouldCreateButtons then
    hook.run('AddMainMenuItems', self, self.sidebar)
  end
end

function PANEL:OpenMenu(panel, data)
  if !IsValid(self.menu) then
    self.menu = theme.CreatePanel(panel, self)

    if self.menu.set_data then
      self.menu:set_data(data)
    end
  else
    if self.menu.Close then
      self.menu:Close(function()
        self:OpenMenu(panel, data)
      end)
    else
      self.menu:SafeRemove()
      self:OpenMenu(panel, data)
    end
  end
end

function PANEL:to_main_menu(bFromRight)
  self:RecreateSidebar(true)

  self.sidebar:SetPos(bFromRight and ScrW() or -self.sidebar:GetWide(), theme.GetOption('MainMenu_SidebarY'))
  self.sidebar:SetDisabled(true)
  self.sidebar:MoveTo(theme.GetOption('MainMenu_SidebarX'), theme.GetOption('MainMenu_SidebarY'), 0.5, 0, 0.5, function()
    self.sidebar:SetDisabled(false)
  end)

  self.menu:MoveTo(bFromRight and -self.menu:GetWide() or ScrW(), 0, 0.5, 0, 0.5, function()
    if self.menu.Close then
      self.menu:Close()
    else
      self.menu:SafeRemove()
    end
  end)
end

function PANEL:notify(text)
  local panel = vgui.Create('fl_notification', self)
  panel:SetText(text)
  panel:SetLifetime(6)
  panel:SetTextColor(Color('pink'))
  panel:SetBackgroundColor(Color(50, 50, 50, 220))

  local w, h = panel:GetSize()
  panel:SetPos(ScrW() * 0.5 - w * 0.5, ScrH() - 128)

  function panel:PostThink() self:MoveToFront() end
end

function PANEL:add_button(text, callback)
  local button = vgui.Create('fl_button', self)
  button:SetSize(theme.GetOption('MainMenu_SidebarWidth'), theme.GetOption('MainMenu_SidebarButtonHeight'))
  button:SetText(string.utf8upper(text))
  button:SetDrawBackground(false)
  button:SetFont(theme.GetFont('Menu_Larger'))
  button:SetPos(theme.GetOption('MainMenu_SidebarButtonOffsetX'), 0)
  button:SetTextAutoposition(false)
  button:SetCentered(theme.GetOption('MainMenu_SidebarButtonCentered'))
  button:SetTextOffset(8)

  button.DoClick = function(btn)
    surface.PlaySound(theme.GetOption('Button_Click_Success'))
  
    btn:SetActive(true)

    if IsValid(self.prevButton) and self.prevButton != btn then
      self.prevButton:SetActive(false)
    end

    self.prevButton = btn

    if isfunction(callback) then
      callback(btn)
    elseif isstring(callback) then
      self:OpenMenu(callback)
    end
  end

  self.sidebar:AddPanel(button)
  self.sidebar:AddSpace(6)

  return button
end

vgui.Register('fl_main_menu', PANEL, 'EditablePanel')
