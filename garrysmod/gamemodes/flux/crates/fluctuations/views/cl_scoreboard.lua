local PANEL = {}
PANEL.player_cards = {}

function PANEL:Init()
  self.scroll_panel = vgui.Create('DScrollPanel', self)
  self.scroll_panel:SetPos(0, 0)
  self.scroll_panel:SetSize(self:get_menu_size())
end

function PANEL:Paint(w, h)
  Theme.hook('PaintScoreboard', self, w, h)
end

function PANEL:rebuild()
  local w, h = self:GetSize()

  if hook.run('PreRebuildScoreboard', self, w, h) != nil then
    return
  end

  for k, v in ipairs(self.player_cards) do
    if IsValid(v) then
      v:safe_remove()
    end

    self.player_cards[k] = nil
  end

  local cur_y = Font.scale(40)
  local card_tall = Font.scale(32) + 8
  local margin = Font.scale(4)

  for k, v in ipairs(_player.GetAll()) do
    if !v:has_initialized() then continue end

    local player_card = vgui.Create('fl_scoreboard_player', self)
    player_card:SetSize(w - 8, card_tall)
    player_card:SetPos(4, cur_y)
    player_card:set_player(v)

    self.scroll_panel:AddItem(player_card)

    cur_y = cur_y + card_tall + margin

    table.insert(self.player_cards, player_card)
  end

  hook.run('RebuildScoreboard', self, w, h)
end

function PANEL:get_menu_size()
  return Font.scale(1280), Font.scale(900)
end

vgui.Register('fl_scoreboard', PANEL, 'fl_base_panel')

local PANEL = {}
PANEL.player = false

function PANEL:Paint(w, h)
  draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background_light'))
end

function PANEL:set_player(player)
  self.player = player

  self:rebuild()
end

function PANEL:rebuild()
  if !self.player then return end

  if IsValid(self.avatar_panel) then
    self.avatar_panel:safe_remove()
    self.name_label:safe_remove()
  end

  local player = self.player

  self.avatar_panel = vgui.Create('AvatarImage', self)
  self.avatar_panel:set_size_ex(32, 32)
  self.avatar_panel:SetPos(4, 4)
  self.avatar_panel:SetPlayer(player, 64)

  self.name_label = vgui.Create('DLabel', self)
  self.name_label:SetText(player:name())
  self.name_label:SetPos(Font.scale(32) + 16, self:GetTall() * 0.5 - util.text_height(player:name(), Theme.get_font('text_normal')) * 0.5)
  self.name_label:SetFont(Theme.get_font('text_normal'))
  self.name_label:SetTextColor(Theme.get_color('text'))
  self.name_label:SizeToContents()

  hook.run('RebuildScoreboardPlayerCard', self, player)
end

vgui.Register('fl_scoreboard_player', PANEL, 'fl_base_panel')
