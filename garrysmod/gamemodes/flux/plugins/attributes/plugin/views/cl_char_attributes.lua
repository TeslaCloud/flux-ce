local PANEL = {}
PANEL.id = 'attributes'
PANEL.text = t'char_create.attributes'
PANEL.model = ''
PANEL.models = {}
PANEL.buttons = {}

function PANEL:Init()
  self.points = 30

  self.Label = vgui.Create('DLabel', self)
  self.Label:SetPos(32, 64)
  self.Label:SetSize(128, 32)
  self.Label:SetText('Points: '..self.points)
  self.Label:SetFont(theme.GetFont('text_normal'))

  self.List = vgui.Create('fl_sidebar', self)
  self.List:SetPos(32, 100)
  self.List:SetSize(ScrW() / 3, ScrH() - 290)
  self.List:AddSpace(2)
end

function PANEL:Rebuild()

end

function PANEL:OnOpen(parent)

end

function PANEL:OnClose(parent)

end

vgui.Register('flCharCreationAttributes', PANEL, 'flCharCreationBase')
