local PANEL = {}

--- Creates the player list, the player info header and the permissions editor. The last two
-- stay hidden until a player is selected.
function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()

  self.player_list = vgui.Create('DListView', self)
  self.player_list:DockMargin(4, 4, 2, 4)
  self.player_list:Dock(LEFT)
  self.player_list:AddColumn(t('ui.admin.players'), 1)
  self.player_list:SetWide(scrw / 6)

  for k, v in player.Iterator() do
    self.player_list:AddLine(v:steam_name(true)..' ('..v:name(true)..')').player = v
  end

  self.player_list.OnRowSelected = function(list, index, panel)
    if self:get_player() != panel.player then
      self:set_player(panel.player)
    end
  end

  self.player_info = vgui.Create('fl_player_info', self)
  self.player_info:SetVisible(false)

  self.perm_editor = vgui.Create('fl_permissions_editor', self)
  self.perm_editor:SetVisible(false)
end

--- Docks and sizes the info header and the permissions editor once the admin panel has opened
-- this page.
function PANEL:on_opened()
  local scrw, scrh = ScrW(), ScrH()

  self.player_info:DockMargin(2, 4, 4, 2)
  self.player_info:Dock(TOP)
  self.player_info:SetTall(scrh / 6)

  self.perm_editor:DockMargin(2, 2, 4, 4)
  self.perm_editor:Dock(FILL)
  self.perm_editor:SetSize(
    self:GetWide() - self.player_list:GetWide() - 12,
    self:GetTall() - self.player_info:GetTall() - 12
  )
end

--- Selects a player, showing the info header and the permissions editor for them.
-- @param target [Player]
function PANEL:set_player(target)
  if !self:get_player() then
    self.player_info:SetVisible(true)
    self.perm_editor:SetVisible(true)
  end

  self.active_player = target
  self.player_info:set_player(target)
  self.perm_editor:set_player(target)
end

--- Returns the selected player.
-- @return [Player the player, or nil if none has been selected]
function PANEL:get_player()
  return self.active_player
end

vgui.Register('fl_player_management', PANEL, 'fl_base_panel')

PANEL = {}

--- Creates the avatar, the name and role labels and the button that opens the role selector.
function PANEL:Init()
  self.avatar = vgui.Create('fl_avatar_panel', self)

  self.name_label = vgui.Create('DLabel', self)
  self.name_label:SetFont(Theme.get_font('text_normal_large'))
  self.name_label:SetTextColor(color_white)

  self.role_label = vgui.Create('DLabel', self)
  self.role_label:SetFont(Theme.get_font('text_normal'))
  self.role_label:SetTextColor(color_white)

  self.role_edit = vgui.Create('fl_button', self)
  self.role_edit:set_icon('fa-edit')
  self.role_edit:set_centered(true)
  self.role_edit:SetDrawBackground(false)
  self.role_edit.DoClick = function(btn)
    local selector = vgui.Create('fl_selector')
    selector:set_title(t'ui.admin.selector.title')
    selector:set_text(t'ui.admin.selector.message')
    selector:set_value(t'ui.admin.selector.roles')

    for k, v in pairs(Bolt:get_roles()) do
      selector:add_choice(v.name, function()
        Cable.send('fl_bolt_set_role', self.player, v.role_id)

        timer.Simple(0.05, function()
          self:rebuild()
        end)
      end)
    end
  end
end

--- Positions the avatar on the right and the labels and the role button on the left.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  self.avatar:SetSize(h - 16, h - 16)
  self.avatar:SetPos(w - self.avatar:GetWide() - 8, 8)

  self.name_label:SetPos(4, 4)

  self.role_label:SetPos(4, 4 + self.name_label:GetTall())
  self.role_edit:set_icon_size(self.role_label:GetTall())
  self.role_edit:SetSize(self.role_label:GetTall(), self.role_label:GetTall())
  self.role_edit:SetPos(8 + self.role_label:GetWide(), 4 + self.name_label:GetTall())
end

--- Sets the player to display and refreshes the panel.
-- @param target [Player]
function PANEL:set_player(target)
  self.player = target

  self:rebuild()
end

--- Refreshes the avatar, name and role label from the current player.
function PANEL:rebuild()
  local target = self.player

  self.avatar:set_player(target, 128)

  self.name_label:SetText(target:steam_name(true)..' ('..target:name(true)..')')
  self.name_label:SizeToContents()

  self.role_label:SetText(t'ui.admin.role'..': '..target:GetUserGroup():upper())
  self.role_label:SizeToContents()

  self:InvalidateLayout()
end

vgui.Register('fl_player_info', PANEL, 'fl_base_panel')
