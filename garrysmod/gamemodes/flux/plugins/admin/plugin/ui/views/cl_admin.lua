local PANEL = {}
PANEL.curPanel = nil
PANEL.panels = {}

function PANEL:Init()
  local scrW, scrH = ScrW(), ScrH()
  local width, height = self:GetMenuSize()

  self:SetTitle("Admin")
  self:SetSize(width, height)
  self:SetPos(scrW * 0.5 - width * 0.5, scrH * 0.5 - height * 0.5)

  self.sidebar = vgui.Create("flSidebar", self)
  self.sidebar:SetSize(width / 5, height)
  self.sidebar:SetPos(0, 0)

  self:SetKeyboardInputEnabled(true)

  hook.run("AddAdminMenuItems", self, self.sidebar)
end

function PANEL:Paint(w, h)
  DisableClipping(true)

  draw.RoundedBoxOutline(0, -4, -4, w + 8, h + 24, 2, theme.GetColor("Background"))

  DisableClipping(false)
end

function PANEL:PaintOver(w, h)
  theme.Call("AdminPanelPaintOver", self, w, h)
end

function PANEL:AddPanel(id, title, permission, ...)
  self.panels[id] = {
    id = id,
    title = title,
    permission = permission,
    arguments = {...}
  }

  self.sidebar:add_button(title, function(btn)
    self:OpenPanel(id)
  end)
end

function PANEL:RemovePanel(id)
  self.panels[id] = nil
end

function PANEL:OpenPanel(id)
  local panel = self.panels[id]

  if (IsValid(self.curPanel)) then
    self.curPanel:SafeRemove()
  end

  if (istable(panel)) then
    if (panel.permission and !fl.client:HasPermission(panel.permission)) then return end

    local scrW, scrH = ScrW(), ScrH()
    local sW, sH = self.sidebar:GetWide(), self.sidebar:GetTall()

    self.curPanel = theme.CreatePanel(panel.id, self, unpack(panel.arguments))
    self.curPanel:SetPos(sW, 0)
    self.curPanel:SetSize(self:GetWide() - sW, self:GetTall())

    if (self.curPanel.OnOpened) then
      self.curPanel:OnOpened(self, panel)
    end
  end
end

function PANEL:SetFullscreen(bFullscreen)
  if (bFullscreen) then
    self.sidebar:MoveTo(-self.sidebar:GetWide(), 0, 0.3)
    self:SetTitle("")

    self.backBtn = vgui.Create("DButton", self)
    self.backBtn:SetPos(0, 0)
    self.backBtn:SetSize(100, 0)
    self.backBtn:SetText("")

    self.backBtn.Paint = function(btn, w, h)
      local font = fl.fonts:GetSize(theme.GetFont("Text_Small"), 16)
      local fontSize = util.font_size(font)

      fl.fa:Draw("fa-chevron-left", 6, 5, 14, Color(255, 255, 255))
      draw.SimpleText("Go Back", font, 24, 3 * (16 / fontSize), Color(255, 255, 255))
    end

    self.backBtn.DoClick = function(btn)
      self:SetFullscreen(false)
    end
  else
    self.sidebar:MoveTo(0, 0, 0.3)
    self:SetTitle("Admin")

    self.backBtn:SafeRemove()
  end
end

function PANEL:GetMenuSize()
  return font.Scale(1280), font.Scale(900)
end

vgui.Register("flAdminPanel", PANEL, "flBasePanel")

concommand.Add("fl_admin_test", function()
  if (IsValid(AdminPanel)) then
    AdminPanel:SafeRemove()
  else
    AdminPanel = vgui.Create("flAdminPanel")
    AdminPanel:MakePopup()
  end
end)
