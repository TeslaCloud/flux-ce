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

  self.stage_list = vgui.Create('fl_horizontalbar', self)
  self.stage_list:SetSize(self.panel:GetWide(), theme.GetOption('MainMenu_SidebarButtonHeight'))
  self.stage_list:SetPos(x, y + self.panel:GetTall() + self.next:GetTall() * 2)
  self.stage_list:SetOverlap(4)
  self.stage_list:SetCentered(true)

  self:RebuildStageList()
end

function PANEL:RebuildStageList()
  self.stage_list:Clear()

  for k, v in ipairs(self.stages) do
    local button = vgui.Create('fl_button', self.stage_list)
    button:SetSize(self.panel:GetWide() / 5, theme.GetOption('MainMenu_SidebarButtonHeight'))
    button:SetIcon('fa-chevron-right', true)
    button:SetIconSize(16)
    button:SetFont(theme.GetFont('Text_NormalSmaller'))
    button:SetTitle(t(v))
    button:SetDrawBackground(false)
    button:SizeToContents()
    button:SetCentered(true)

    if k > self.stage then
      button:SetEnabled(false)
    elseif k == self.stage then
      button:SetEnabled(true)
      button:SetTextColor(theme.GetColor('Accent'))
    end

    button.DoClick = function(btn)
      local cur_time = CurTime()

      if !self.stage_list.next_click or self.stage_list.next_click <= cur_time then
        if self.stage > k then
          timer.Create('flux_char_panel_change', .1, self.stage - k, function()
            self:PrevStage()
          end)
  
          self.stage_list.next_click = cur_time + 1
        end
      end
    end

    self.stage_list:AddPanel(button)
  end
end

function PANEL:SetStage(stage)
  self:OpenPanel(self.stages[stage])
  self.stage = stage
  self:RebuildStageList()

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

      return false
    end
  end

  local success, error = hook.run('PreStageChange', self.stages[self.stage],  self.panel)

  if success == false then
    self:GetParent():notify(error or t('char_create.unknown_error'))

    return false
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
    local parent = self:GetParent()
    parent:RecreateSidebar(true)

    local sidebar = parent.sidebar
    sidebar:SetPos(-parent.sidebar:GetWide(), theme.GetOption('MainMenu_SidebarY'))
    sidebar:SetDisabled(true)
    sidebar:MoveTo(theme.GetOption('MainMenu_SidebarX'), theme.GetOption('MainMenu_SidebarY'), .5, 0, .5, function()
      sidebar:SetDisabled(false)
    end)

    parent.menu:MoveTo(ScrW(), 0, .5, 0, .5, function()
      if parent.menu.Close then
        parent.menu:Close()
      else
        parent.menu:SafeRemove()
      end
    end)
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

function PANEL:ClearData()
  table.Empty(self.char_data)
end

function PANEL:OpenPanel(id)
  local x, y = self:GetWide() / 4, self:GetTall() / 6 + 8

  if IsValid(self.panel) then
    if self.panel.OnClose then
      self.panel:OnClose(self)
    end

    local to = self:GetWide()

    if self.stage < table.KeyFromValue(self.stages, id) then
      to = -self.panel:GetWide()
    end

    self.panel:MoveTo(to, y, .5, 0, .5)
  end

  self.panel = theme.CreatePanel(id, self)
  self.panel:SetSize(self:GetWide() / 2, self:GetTall() / 2)

  local from

  if !self.stages then
    from = x
  elseif self.stage < table.KeyFromValue(self.stages, id) then
    from = self:GetWide()
  else
    from = -self.panel:GetWide()
  end

  self.panel:SetPos(from, y)
  self.panel:MoveTo(x, y, .5, 0, .5)

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
