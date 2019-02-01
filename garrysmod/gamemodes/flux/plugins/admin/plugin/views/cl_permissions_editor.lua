local PANEL = {}
PANEL.permission_value = PERM_NO
PANEL.permission = {}

function PANEL:rebuild()
  if IsValid(self.container) then
    self.container:safe_remove()
  end

  local width, height = self:GetWide(), self:GetTall()
  local font = font.size(theme.get_font('text_normal_smaller'), font.scale(18))
  local font_size = draw.GetFontHeight(font)
  local permission = self:get_permission()
  local quarter = width * 0.25

  self.container = vgui.Create('fl_base_panel', self)
  self.container:SetSize(width, height)
  self.container:SetPos(0, 0)

  self.title = vgui.Create('DLabel', self.container)
  self.title:SetPos(0, height * 0.5 - font_size * 0.5)
  self.title:SetFont(font)
  self.title:SetText(permission.name or 'No Permission')
  self.title:SetSize(quarter, height)

  if permission.description then
    self.title:SetTooltip(permission.description)
  end

  self.button = vgui.Create('DButton', self.container)
  self.button:SetPos(quarter, 0)
  self.button:SetSize(quarter * 0.9, height)
  self.button:SetText('')
  self.button.perm_value = PERM_ALLOW
  self.button.Paint = function(btn, w, h) theme.call('PaintPermissionButton', self, btn, w, h) end
  self.button.DoClick = function(btn)
    if btn.is_selected then return end

    surface.PlaySound('buttons/button14.wav')
    self:select_button(btn)
  end

  self.button_no = vgui.Create('DButton', self.container)
  self.button_no:SetPos(quarter * 2, 0)
  self.button_no:SetSize(quarter * 0.9, height)
  self.button_no:SetText('')
  self.button_no.perm_value = PERM_NO
  self.button_no.Paint = function(btn, w, h) theme.call('PaintPermissionButton', self, btn, w, h) end
  self.button_no.DoClick = function(btn)
    if btn.is_selected then return end

    surface.PlaySound('ui/buttonclick.wav')
    self:select_button(btn)
  end

  self.button_never = vgui.Create('DButton', self.container)
  self.button_never:SetPos(quarter * 3, 0)
  self.button_never:SetSize(quarter * 0.9, height)
  self.button_never:SetText('')
  self.button_never.perm_value = PERM_NEVER
  self.button_never.Paint = function(btn, w, h) theme.call('PaintPermissionButton', self, btn, w, h) end
  self.button_never.DoClick = function(btn)
    if btn.is_selected then return end

    surface.PlaySound('buttons/button10.wav')
    self:select_button(btn)
  end
end

function PANEL:select_button(button)
  local value = button.perm_value or PERM_NO
  local perm = self:get_permission()

  self.permission_value = value

  button.is_selected = true

  local player = self:get_player()

  if IsValid(player) and (value != player:get_permission(perm.id)) then
    cable.send('fl_bolt_set_permission', player, perm.id, value)
  end

  if IsValid(self.prev_button) and self.prev_button != button then
    self.prev_button.is_selected = false
  end

  self.prev_button = button
end

function PANEL:set_player(player)
  self.active_player = player
end

function PANEL:get_player()
  return self.active_player
end

function PANEL:set_permission(perm)
  self.permission = perm or {}

  self:rebuild()
end

function PANEL:get_permission()
  return self.permission
end

function PANEL:get_value()
  return self.permission_value
end

function PANEL:set_value(perm)
  if perm == PERM_ALLOW then
    self:select_button(self.button)
  elseif perm == PERM_NEVER then
    self:select_button(self.button_never)
  else
    self:select_button(self.button_no)
  end
end

vgui.Register('fl_permission', PANEL, 'fl_base_panel')

local PANEL = {}

function PANEL:Init()
  self.permissions = {}

  self:rebuild()
end

function PANEL:Paint(w, h)
  theme.call('PaintPermissionEditor', self, w, h)
end

function PANEL:get_permissions()
  local perm_list = {}

  for k, v in pairs(self.permissions) do
    if v:get_value() != PERM_NO then
      perm_list[v:get_permission()] = v:get_value()
    end
  end

  return perm_list
end

function PANEL:set_permissions(perm_list)
  for k, v in pairs(perm_list) do
    self.permissions[k]:set_value(tonumber(v))
  end
end

function PANEL:set_player(player)
  self.active_player = player

  self:rebuild()

  self:set_permissions(player:get_permissions())
end

function PANEL:get_player()
  return self.active_player
end

function PANEL:rebuild()
  if IsValid(self.list_layout) then
    self.list_layout:safe_remove()
  end

  local permissions = Bolt:get_permissions()
  local width, height = self:GetWide(), self:GetTall()

  self.scroll_panel = vgui.Create('DScrollPanel', self)
  self.scroll_panel:SetSize(width, height)

  self.list_layout = vgui.Create('DListLayout', self.scroll_panel)
  self.list_layout:SetSize(width, height)

  for category, perms in SortedPairs(permissions) do
    local collapsible_category = vgui.Create('DCollapsibleCategory', self.list_layout)
    collapsible_category:SetLabel(t(category))
    collapsible_category:SetSize(width, 21)

    local list = vgui.Create('DListLayout', list_layout)

    collapsible_category:SetContents(list)

    if table.count(perms) > 1 then
      local panel = vgui.create('fl_base_panel')

      local category_buttons = {
        t'admin.allow_all',
        t'admin.no_all',
        t'admin.never_all'
      }

      local quarter = width / 4

      for k, v in pairs(category_buttons) do
        local button = vgui.create('fl_button', panel)
        button:SetSize(quarter * 0.9, 20)
        button:SetPos(quarter * k, 2)
        button:SetFont(theme.get_font('text_small'))
        button:set_text(v)
        button:set_centered(true)
        button.DoClick = function(btn)
          local can_click = false

          for k1, v1 in pairs(perms) do
            if self.permissions[v1.id]:get_value() != k - 1 then
              can_click = true

              break
            end
          end

          if !can_click then return end

          surface.PlaySound('buttons/button4.wav')

          for k1, v1 in pairs(perms) do
            self.permissions[v1.id]:set_value(k - 1)
          end
        end
      end

      list:Add(panel)
    end

    local cur_y = 0

    for k, v in SortedPairs(perms) do
      local button = vgui.Create('fl_permission', self)
      button:SetSize(width, 20)
      button:set_permission(v)
      button:set_value(PERM_NO)
      button:set_player(self:get_player())

      list:Add(button)

      self.permissions[v.id] = button
    end
  end
end

vgui.Register('fl_permissions_editor', PANEL, 'fl_base_panel')
