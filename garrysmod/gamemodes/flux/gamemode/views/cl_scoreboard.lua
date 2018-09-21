local PANEL = {}
PANEL.playerCards = {}

function PANEL:Init()
  self.scrollPanel = vgui.Create('DScrollPanel', self)
  self.scrollPanel:SetPos(0, 0)
  self.scrollPanel:SetSize(self:GetMenuSize())
end

function PANEL:Paint(w, h)
  theme.Hook('PaintScoreboard', self, w, h)
end

function PANEL:Rebuild()
  local w, h = self:GetSize()

  if hook.run('PreRebuildScoreboard', self, w, h) != nil then
    return
  end

  for k, v in ipairs(self.playerCards) do
    if IsValid(v) then
      v:SafeRemove()
    end

    self.playerCards[k] = nil
  end

  local curY = font.Scale(40)
  local cardTall = font.Scale(32) + 8
  local margin = font.Scale(4)

  for k, v in ipairs(_player.GetAll()) do
    if !v:HasInitialized() then continue end

    local playerCard = vgui.Create('fl_scoreboard_player', self)
    playerCard:SetSize(w - 8, cardTall)
    playerCard:SetPos(4, curY)
    playerCard:SetPlayer(v)

    self.scrollPanel:AddItem(playerCard)

    curY = curY + cardTall + margin

    table.insert(self.playerCards, playerCard)
  end

  hook.run('RebuildScoreboard', self, w, h)
end

function PANEL:GetMenuSize()
  return font.Scale(1280), font.Scale(900)
end

vgui.Register('fl_scoreboard', PANEL, 'fl_base_panel')

local PANEL = {}
PANEL.player = false

function PANEL:SetPlayer(player)
  self.player = player

  self:Rebuild()
end

function PANEL:Paint(w, h)
  draw.RoundedBox(0, 0, 0, w, h, theme.GetColor('background_light'))
end

function PANEL:Rebuild()
  if !self.player then return end

  if IsValid(self.avatarPanel) then
    self.avatarPanel:SafeRemove()
    self.nameLabel:SafeRemove()
  end
  
  local player = self.player

  self.avatarPanel = vgui.Create('AvatarImage', self)
  self.avatarPanel:SetSizeEx(32, 32)
  self.avatarPanel:SetPos(4, 4)
  self.avatarPanel:SetPlayer(player, 64)

  self.nameLabel = vgui.Create('DLabel', self)
  self.nameLabel:SetText(player:Name())
  self.nameLabel:SetPos(font.Scale(32) + 16, self:GetTall() * 0.5 - util.text_height(player:Name(), theme.GetFont('text_normal')) * 0.5)
  self.nameLabel:SetFont(theme.GetFont('text_normal'))
  self.nameLabel:SetTextColor(theme.GetColor('Text'))
  self.nameLabel:SizeToContents()

  hook.run('RebuildScoreboardPlayerCard', self, player)
end

vgui.Register('fl_scoreboard_player', PANEL, 'fl_base_panel')
