local PANEL = {}
PANEL.char_data = {}

function PANEL:Init()
  self:SetPos(0, 0)
  self:SetSize(ScrW(), ScrH())
  self:SetTitle(t'char_create.title')

  self.btnClose:SafeRemove()

  self:OpenPanel(theme.GetOption('CharCreation_FirstPanel'))

  self.stage = 1
  self.stages = {}

  hook.run('AddCharacterCreationMenuStages', self)

  local x, y = self.panel:GetPos()

  self.back = vgui.Create('fl_button', self)
  self.back:SetSize(self.panel:GetWide() / 4, theme.GetOption('MainMenu_SidebarButtonHeight'))
  self.back:SetPos(x, y + self.panel:GetTall() + self.back:GetTall())
  self.back:SetIcon('fa-chevron-left')
  self.back:SetIconSize(16)
  self.back:SetFont(theme.GetFont('Text_NormalSmaller'))
  self.back:SetTitle(t('char_create.main_menu'))
  self.back:SetDrawBackground(false)
  self.back:SetCentered(true)

  self.back.DoClick = function(btn)
    surface.PlaySound(theme.GetOption('Button_Click_Success'))

    self:PrevStage()
  end

  self.next = vgui.Create('fl_button', self)
  self.next:SetSize(self.panel:GetWide() / 4, theme.GetOption('MainMenu_SidebarButtonHeight'))
  self.next:SetPos(x + self.panel:GetWide() - self.next:GetWide(), y + self.panel:GetTall() + self.next:GetTall())
  self.next:SetIcon('fa-chevron-right', true)
  self.next:SetIconSize(16)
  self.next:SetFont(theme.GetFont('Text_NormalSmaller'))
  self.next:SetTitle(t('char_create.next'))
  self.next:SetDrawBackground(false)
  self.next:SetCentered(true)

  self.next.DoClick = function(btn)
    surface.PlaySound(theme.GetOption('Button_Click_Success'))

    self:NextStage()
  end
end

function PANEL:SetStage(stage)
  self.stage = stage

  self:OpenPanel(self.stages[stage])

  if self.stage == 1 then
    self.back:SetTitle(t('char_create.main_menu'))
  else
    self.back:SetTitle(t('char_create.back'))
  end

  if self.stage == #self.stages then
    self.next:SetTitle(t('char_create.create'))
  else
    self.next:SetTitle(t('char_create.next'))
  end
end

function PANEL:NextStage()
  if self.panel and self.panel.OnValidate then
    local success, error = self.panel:OnValidate()

    if success == false then
      self:GetParent():notify(error or t('char_create.unknown_error'))

      return
    end
  end

  local success, error = hook.run('PreStageChange', self.stages[self.stage],  self.panel)

  if success == false then
    self:GetParent():notify(error or t('char_create.unknown_error'))

    return
  end

  if self.stage != #self.stages then
    self:SetStage(self.stage + 1)
  else
    if self.panel.OnClose then
      self.panel:OnClose(self)
    end

    netstream.Start('CreateCharacter', self.char_data)
  end
end

function PANEL:PrevStage()
  if self.stage != 1 then
    self:SetStage(self.stage - 1)
  else
    self:GetParent():RecreateSidebar(true)

    if self:GetParent().menu.Close then
      self:GetParent().menu:Close()
    else
      self:GetParent().menu:SafeRemove()
    end
  end
end

function PANEL:Close(callback)
  self:SetVisible(false)
  self:Remove()

  if callback then
    callback()
  end
end

function PANEL:CollectData(newData)
  table.safe_merge(self.char_data, newData)
end

function PANEL:OpenPanel(id)
  if IsValid(self.panel) then
    if self.panel.OnClose then
      self.panel:OnClose(self)
    end

    self.panel:SafeRemove()
  end

  self.panel = theme.CreatePanel(id, self)
  self.panel:SetSize(self:GetWide() / 2, self:GetTall() / 2)
  self.panel:SetPos(self:GetWide() / 4, self:GetTall() / 6 + 8)

  if self.panel.OnOpen then
    self.panel:OnOpen(self)
  end

  hook.run('CharPanelCreated', id, self.panel)
end

function PANEL:add_stage(id, index)
  if index then
    table.insert(self.stages, index, id)
  else
    table.insert(self.stages, id)
  end
end

function PANEL:Paint(w, h)
  if self:IsVisible() then
    theme.Hook('PaintCharCreationMainPanel', self, w, h)
  end
end

vgui.Register('flCharacterCreation', PANEL, 'fl_frame')
