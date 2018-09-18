local PANEL = {}
PANEL.chars = {}

function PANEL:Init()
  local scrW, scrH = ScrW(), ScrH()

  self:SetPos(0, 0)
  self:SetSize(scrW, scrH)

  self.btnClose:SafeRemove()

  self.list = vgui.Create('fl_horizontalbar', self)
  self.list:SetSize(scrW / 2, scrH / 2)
  self.list:SetPos(scrW / 2 - self.list:GetWide() / 2, scrH / 2 - self.list:GetTall() / 2)
  self.list:SetCentered(true)

  self.back = vgui.Create('fl_button', self)
  self.back:SetSize(self.list:GetWide() / 4, theme.GetOption('MainMenu_SidebarButtonHeight'))
  self.back:SetPos(scrW / 2 + self.list:GetWide() / 2 - self.back:GetWide(), scrH / 2 + self.list:GetTall() / 2 + self.back:GetTall())
  self.back:SetIcon('fa-chevron-right', true)
  self.back:SetIconSize(16)
  self.back:SetFont(theme.GetFont('Text_NormalSmaller'))
  self.back:SetTitle(t('char_create.main_menu'))
  self.back:SetDrawBackground(false)
  self.back:SetCentered(true)

  self.back.DoClick = function(btn)
    surface.PlaySound(theme.GetOption('Button_Click_Success'))

    local parent = self:GetParent()
    parent:RecreateSidebar(true)

    local sidebar = parent.sidebar
    sidebar:SetPos(scrW, theme.GetOption('MainMenu_SidebarY'))
    sidebar:SetDisabled(true)
    sidebar:MoveTo(theme.GetOption('MainMenu_SidebarX'), theme.GetOption('MainMenu_SidebarY'), .5, 0, .5, function()
      sidebar:SetDisabled(false)
    end)

    parent.menu:MoveTo(-parent.menu:GetWide(), 0, .5, 0, .5, function()
      if parent.menu.Close then
        parent.menu:Close()
      else
        parent.menu:SafeRemove()
      end
    end)
  end

  for k, v in ipairs(fl.client:GetAllCharacters()) do
    self.chars[k] = vgui.Create('fl_character_panel', self)
    self.chars[k]:SetSize(self.list:GetWide() / 4, self.list:GetTall())
    self.chars[k]:SetCharacter(v)

    self.list:AddPanel(self.chars[k])
  end
end

function PANEL:Close(callback)
  self:SetVisible(false)
  self:Remove()

  if callback then
    callback()
  end
end

function PANEL:Paint(w, h)
  if self:IsVisible() then
    theme.Hook('PaintCharCreationLoadPanel', self, w, h)
  end
end

vgui.Register('fl_character_load', PANEL, 'fl_frame')

local PANEL = {}

function PANEL:Init()
  self:SetPaintBackground(false)

  self.model = vgui.Create('DModelPanel', self)
  self.model:SetFOV(50)
  self.model:SetCamPos(Vector(50, 0, 35))
  self.model:SetLookAt(Vector(0, 0, 35))
  self.model:SetAnimated(true)
  self.model.LayoutEntity = function(entity) end

  self.select = vgui.Create('fl_button', self)
  self.select:SetIcon('fa-check')
  self.select:SetIconSize(16)
  self.select:SetFont(theme.GetFont('Text_NormalSmaller'))
  self.select:SetTitle(t('char_create.select'))
  self.select:SetTextColor(Color('lightgreen'))
  self.select:SetDrawBackground(false)
  self.select:SetCentered(true)
  self.select.DoClick = function(btn)
    netstream.Start('PlayerSelectCharacter', self.char_data.character_id)
  end

  self.delete = vgui.Create('fl_button', self)
  self.delete:SetIcon('fa-trash')
  self.delete:SetIconSize(16)
  self.delete:SetFont(theme.GetFont('Text_NormalSmaller'))
  self.delete:SetTextColor(Color('red'))
  self.delete:SetDrawBackground(false)
  self.delete:SetCentered(true)
  self.delete.DoClick = function(btn)
    surface.PlaySound('vo/npc/male01/answer37.wav')
    Derma_StringRequest(t('char_create.delete_confirm'), t('char_create.delete_confirm_msg', { self.char_data.name }), '',
    function()
    
    end,
    nil, t('char_create.delete'))
  end
end

function PANEL:SetCharacter(char_data)
  self.char_data = char_data

  self.model:SetModel(char_data.model)
  self.model.Entity:SetSequence(ACT_IDLE)

  hook.run('PanelCharacterSet', self, char_data)
end

function PANEL:Paint(w, h)
  if self:IsVisible() then
    theme.Hook('PaintCharPanel', self, w, h)
  end
end

function PANEL:PerformLayout(w, h)
  self.model:SetPos(4, 28)
  self.model:SetSize(w - 4, h * .80)

  self.select:SetPos(4, h - theme.GetOption('MainMenu_SidebarButtonHeight'))
  self.select:SetSize(w / 3 * 2 - 4, theme.GetOption('MainMenu_SidebarButtonHeight'))

  self.delete:SetPos(w / 3 * 2, h - theme.GetOption('MainMenu_SidebarButtonHeight'))
  self.delete:SetSize(w / 3 - 4, theme.GetOption('MainMenu_SidebarButtonHeight'))
end

vgui.Register('fl_character_panel', PANEL, 'DPanel')
