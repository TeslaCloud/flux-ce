local PANEL = {}
PANEL.CharData = {}

function PANEL:Init()
  self:SetPos(400, 0)
  self:SetSize(ScrW() - 400, ScrH())
  self:SetTitle(t"char_create.title")

  self.btnClose:SafeRemove()

  self:OpenPanel("CharCreation_General")
end

function PANEL:Close(callback)
  self:SetVisible(false)
  self:Remove()

  if callback then
    callback()
  end
end

function PANEL:CollectData(newData)
  table.safe_merge(self.CharData, newData)
end

function PANEL:OpenPanel(id)
  if IsValid(self.panel) then
    if self.panel.OnClose then
      self.panel:OnClose(self)
    end

    self.panel:SafeRemove()
  end

  self.panel = theme.CreatePanel(id, self)
  self.panel:SetSize(self:GetWide(), self:GetTall() - 90)
  self.panel:SetPos(0, 90)

  if self.panel.OnOpen then
    self.panel:OnOpen(self)
  end

  hook.run("CharPanelCreated", id, self.panel)

  if IsValid(self.finishButton) then
    self.finishButton:SafeRemove()
  end

  self.finishButton = vgui.Create("flButton", self)
  self.finishButton:SetTitle(t('char_create.create'))
  self.finishButton:SetPos(self:GetWide() - 250 + theme.GetOption("FinishButtonOffsetX"), self:GetTall() - 120 + theme.GetOption("FinishButtonOffsetY"))
  self.finishButton:SetDrawBackground(false)
  self.finishButton:SetFont(theme.GetFont("Text_Large"))
  self.finishButton:SizeToContents()

  self.finishButton.DoClick = function(btn)
    if self.panel.OnClose then
      self.panel:OnClose(self)
    end

    netstream.Start("CreateCharacter", self.CharData)
  end

  self.finishButton:MoveToFront()
end

--[[These have translations issues and are currently not supported for translation.]]

function PANEL:AddSidebarItems(sidebar, panel)
  local button = panel:add_button(t('char_create.gen_text'), function(btn)
    self:OpenPanel("CharCreation_General")
  end)

  button:SetActive(true)
  panel.prevButton = button

  panel:add_button(t('char_create.model_button'), function(btn)
    self:OpenPanel("CharCreation_Model")
  end)

  hook.run("AddCharacterCreationMenuItems", self, panel, sidebar)
end

function PANEL:Paint(w, h)
  draw.RoundedBox(0, 0, 0, w, h, theme.GetColor("MainDark"):darken(10))
  draw.SimpleText(t"char_create.text", theme.GetFont("Text_Large"), 24, 42)
end

vgui.Register("flCharacterCreation", PANEL, "flFrame")
