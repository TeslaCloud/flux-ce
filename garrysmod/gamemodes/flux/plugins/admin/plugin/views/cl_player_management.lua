local PANEL = {}

function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()

  self.player_list = vgui.create('DListView', self)
  self.player_list:DockMargin(4, 4, 2, 4)
  self.player_list:Dock(LEFT)
  self.player_list:AddColumn(t'admin.players')
  self.player_list:SetWide(scrw / 6)

  for k, v in ipairs(player.all()) do
    self.player_list:AddLine(v:steam_name(true)..' ('..v:name(true)..')').player = v
  end

  self.player_list.OnRowSelected = function(list, index, panel)
    if self:get_player() != panel.player then
      self:set_player(panel.player)
    end
  end

  self.player_info = vgui.create('fl_player_info', self)
  self.player_info:SetVisible(false)

  self.perm_editor = vgui.create('fl_permissions_editor', self)
  self.perm_editor:SetVisible(false)
end

function PANEL:on_opened()
  local scrw, scrh = ScrW(), ScrH()

  self.player_info:DockMargin(2, 4, 4, 2)
  self.player_info:Dock(TOP)
  self.player_info:SetTall(scrh / 6)

  self.perm_editor:DockMargin(2, 2, 4, 4)
  self.perm_editor:Dock(FILL)
  self.perm_editor:SetSize(self:GetWide() - self.player_list:GetWide() - 12, self:GetTall() - self.player_info:GetTall() - 12)
end

function PANEL:set_player(player)
  if !self:get_player() then
    self.player_info:SetVisible(true)
    self.perm_editor:SetVisible(true)
  end

  self.active_player = player
  self.player_info:set_player(player)
  self.perm_editor:set_player(player)
end

function PANEL:get_player()
  return self.active_player
end

vgui.Register('fl_player_management', PANEL, 'fl_base_panel')

PANEL = {}

function PANEL:Init()
  self.avatar = vgui.create('AvatarImage', self)
  self.avatar:SetTooltip(t'admin.avatar_tooltip')

  self.avatar.button = vgui.create('DButton', self.avatar)
  self.avatar.button:Dock(FILL)
  self.avatar.button:SetText('')
  self.avatar.button.Paint = function()
  end

  self.avatar.button.DoClick = function(pnl)
    local player = self.player

    if IsValid(player) then
      player:ShowProfile()
    end
  end

  self.avatar.button.DoRightClick = function(pnl)
    local player = self.player

    if IsValid(player) then
      SetClipboardText(player:SteamID())
    end
  end

  self.name_label = vgui.create('DLabel', self)
  self.name_label:SetFont(theme.get_font('text_normal_large'))
  self.name_label:SetTextColor(color_white)

  self.role_label = vgui.create('DLabel', self)
  self.role_label:SetFont(theme.get_font('text_normal'))
  self.role_label:SetTextColor(color_white)

  self.role_edit = vgui.create('fl_button', self)
  self.role_edit:set_icon('fa-edit')
  self.role_edit:set_centered(true)
  self.role_edit:SetDrawBackground(false)
  self.role_edit.DoClick = function(btn)
    local selector = vgui.create('fl_selector')
    selector:set_title(t'admin.selector.title')
    selector:set_text(t'admin.selector.message')
    selector:set_value(t'admin.selector.roles')

    for k, v in pairs(Bolt:get_roles()) do
      selector:add_choice(v.name, function()
        cable.send('fl_bolt_set_role', self.player, v.role_id)

        timer.simple(0.05, function()
          self:rebuild()
        end)
      end)
    end
  end
end

function PANEL:PerformLayout(w, h)
  self.avatar:SetSize(h - 16, h - 16)
  self.avatar:SetPos(w - self.avatar:GetWide() - 8, 8)

  self.name_label:SetPos(4, 4)

  self.role_label:SetPos(4, 4 + self.name_label:GetTall())
  self.role_edit:set_icon_size(self.role_label:GetTall())
  self.role_edit:SetSize(self.role_label:GetTall(), self.role_label:GetTall())
  self.role_edit:SetPos(8 + self.role_label:GetWide(), 4 + self.name_label:GetTall())
end

function PANEL:set_player(player)
  self.player = player

  self:rebuild()
end

function PANEL:rebuild()
  local player = self.player

  self.avatar:SetPlayer(player, 128)

  self.name_label:SetText(player:steam_name(true)..' ('..player:name(true)..')')
  self.name_label:SizeToContents()

  self.role_label:SetText(t'admin.role'..': '..player:GetUserGroup():upper())
  self.role_label:SizeToContents()

  self:InvalidateLayout()
end

vgui.Register('fl_player_info', PANEL, 'fl_base_panel')
