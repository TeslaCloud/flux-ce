local function PermButtonDoClick(panel, btn)
  panel.permission_value = btn.perm_value or PERM_NO
  btn.is_selected = true

  if IsValid(panel.prev_button) then
    panel.prev_button.is_selected = false
  end

  panel.prev_button = btn
end

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

  self.button_no = vgui.Create('DButton', self.container)
  self.button_no:SetPos(quarter, 0)
  self.button_no:SetSize(quarter * 0.8, height)
  self.button_no:SetText('')
  self.button_no.perm_value = PERM_NO
  self.button_no.Paint = function(btn, w, h) theme.call('PaintPermissionButton', self, btn, w, h) end
  self.button_no.DoClick = function(btn) PermButtonDoClick(self, btn) end

  self.button_allow = vgui.Create('DButton', self.container)
  self.button_allow:SetPos(quarter * 2, 0)
  self.button_allow:SetSize(quarter * 0.8, height)
  self.button_allow:SetText('')
  self.button_allow.perm_value = PERM_ALLOW
  self.button_allow.Paint = function(btn, w, h) theme.call('PaintPermissionButton', self, btn, w, h) end
  self.button_allow.DoClick = function(btn) PermButtonDoClick(self, btn) end

  self.button_never = vgui.Create('DButton', self.container)
  self.button_never:SetPos(quarter * 3, 0)
  self.button_never:SetSize(quarter * 0.8, height)
  self.button_never:SetText('')
  self.button_never.perm_value = PERM_NEVER
  self.button_never.Paint = function(btn, w, h) theme.call('PaintPermissionButton', self, btn, w, h) end
  self.button_never.DoClick = function(btn) PermButtonDoClick(self, btn) end
end

function PANEL:set_permission(perm)
  self.permission = perm or {}

  self:rebuild()
end

function PANEL:get_permission()
  return self.permission
end

vgui.Register('fl_permission', PANEL, 'fl_base_panel')

local PANEL = {}

function PANEL:Init()
  self:rebuild()
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

  for category, perms in pairs(permissions) do
    local collapsible_category = vgui.Create('DCollapsibleCategory', self.list_layout)
    collapsible_category:SetLabel(category)
    collapsible_category:SetSize(width, 21)

    local list = vgui.Create('DListLayout', list_layout)

    collapsible_category:SetContents(list)

    local cur_y = 0

    for k, v in pairs(perms) do
      local btn = vgui.Create('fl_permission')
      btn:SetSize(width, 20)
      btn:set_permission(v)

      local pan = list:Add(btn)

      btn:rebuild()
    end
  end
end

function PANEL:on_opened()
  self:rebuild()
end

vgui.Register('permissions_editor', PANEL, 'fl_base_panel')
