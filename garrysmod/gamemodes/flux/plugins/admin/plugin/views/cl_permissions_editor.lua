local function PermButtonDoClick(panel, btn)
  panel.m_PermissionValue = btn.permValue or PERM_NO
  btn.isSelected = true

  if IsValid(panel.prevBtn) then
    panel.prevBtn.isSelected = false
  end

  panel.prevBtn = btn
end

local PANEL = {}
PANEL.m_PermissionValue = PERM_NO
PANEL.m_Permission = {}

function PANEL:Rebuild()
  if IsValid(self.container) then
    self.container:SafeRemove()
  end

  local width, height = self:GetWide(), self:GetTall()
  local font = font.GetSize(theme.GetFont("Text_NormalSmaller"), font.Scale(18))
  local fontSize = draw.GetFontHeight(font)
  local permission = self:GetPermission()
  local quarter = width * 0.25

  self.container = vgui.Create("flBasePanel", self)
  self.container:SetSize(width, height)
  self.container:SetPos(0, 0)

  self.title = vgui.Create("DLabel", self.container)
  self.title:SetPos(0, height * 0.5 - fontSize * 0.5)
  self.title:SetFont(font)
  self.title:SetText(permission.name or "No Permission")
  self.title:SetSize(quarter, height)

  self.btnNo = vgui.Create("DButton", self.container)
  self.btnNo:SetPos(quarter, 0)
  self.btnNo:SetSize(quarter * 0.8, height)
  self.btnNo:SetText("")
  self.btnNo.permValue = PERM_NO
  self.btnNo.Paint = function(btn, w, h) theme.Call("PaintPermissionButton", self, btn, w, h) end
  self.btnNo.DoClick = function(btn) PermButtonDoClick(self, btn) end

  self.btnAllow = vgui.Create("DButton", self.container)
  self.btnAllow:SetPos(quarter * 2, 0)
  self.btnAllow:SetSize(quarter * 0.8, height)
  self.btnAllow:SetText("")
  self.btnAllow.permValue = PERM_ALLOW
  self.btnAllow.Paint = function(btn, w, h) theme.Call("PaintPermissionButton", self, btn, w, h) end
  self.btnAllow.DoClick = function(btn) PermButtonDoClick(self, btn) end

  self.btnNever = vgui.Create("DButton", self.container)
  self.btnNever:SetPos(quarter * 3, 0)
  self.btnNever:SetSize(quarter * 0.8, height)
  self.btnNever:SetText("")
  self.btnNever.permValue = PERM_NEVER
  self.btnNever.Paint = function(btn, w, h) theme.Call("PaintPermissionButton", self, btn, w, h) end
  self.btnNever.DoClick = function(btn) PermButtonDoClick(self, btn) end
end

function PANEL:SetPermission(perm)
  self.m_Permission = perm or {}

  self:Rebuild()
end

function PANEL:GetPermission()
  return self.m_Permission
end

vgui.Register("flPermission", PANEL, "flBasePanel")

local PANEL = {}

function PANEL:Init()
  self:Rebuild()
end

function PANEL:Rebuild()
  if IsValid(self.listLayout) then
    self.listLayout:SafeRemove()
  end

  local permissions = fl.admin:GetPermissions()
  local width, height = self:GetWide(), self:GetTall()

  self.scrollPanel = vgui.Create("DScrollPanel", self)
  self.scrollPanel:SetSize(width, height)

  self.listLayout = vgui.Create("DListLayout", self.scrollPanel)
  self.listLayout:SetSize(width, height)

  for category, perms in pairs(permissions) do
    local collapsibleCategory = vgui.Create("DCollapsibleCategory", self.listLayout)
    collapsibleCategory:SetLabel(category)
    collapsibleCategory:SetSize(width, 21)

    local list = vgui.Create("DListLayout", listLayout)

    collapsibleCategory:SetContents(list)

    local curY = 0

    for k, v in pairs(perms) do
      local btn = vgui.Create("flPermission")
      btn:SetSize(width, 20)
      btn:SetPermission(v)

      local pan = list:Add(btn)

      btn:Rebuild()
    end
  end
end

function PANEL:OnOpened()
  self:Rebuild()
end

vgui.Register("permissionsEditor", PANEL, "flBasePanel")
