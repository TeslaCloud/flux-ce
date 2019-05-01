local PANEL = {}
PANEL.cur_panel = nil
PANEL.panels = {}

function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()
  local width, height = self:get_menu_size()

  self:SetTitle('Admin')
  self:SetSize(width, height)
  self:SetPos(scrw * 0.5 - width * 0.5, scrh * 0.5 - height * 0.5)

  self.sidebar = vgui.Create('fl_sidebar', self)
  self.sidebar:SetSize(width / 5 - 8, height)
  self.sidebar:SetPos(0, 0)
  self.sidebar.Paint = function(pnl, w, h)
  end

  self:SetKeyboardInputEnabled(true)

  hook.run('AddAdminMenuItems', self, self.sidebar)
end

function PANEL:Paint(w, h)
  DisableClipping(true)

  draw.box_outlined(0, -4, -4, w + 8, h + 24, 2, Theme.get_color('background'))

  DisableClipping(false)

  draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background'):alpha(150))
end

function PANEL:PaintOver(w, h)
  Theme.call('AdminPanelPaintOver', self, w, h)
end

function PANEL:add_panel(id, title, permission, ...)
  self.panels[id] = {
    id = id,
    title = title,
    permission = permission,
    arguments = {...}
  }

  local button = vgui.create('fl_button')
  button:SetWide(self.sidebar:GetWide())
  button:SetDrawBackground(true)
  button:SetFont(Theme.get_font('text_normal'))
  button:set_text(title)
  button:set_text_autoposition(true)
  button:SizeToContentsY()
  button:set_centered(true)
  button.DoClick = function(btn)
    if !self.cur_panel or self.cur_panel.id != id then
      self:open_panel(id)
    end
  end

  self.sidebar:add_panel(button)
  self.sidebar:add_space(2)
end

function PANEL:remove_panel(id)
  self.panels[id] = nil
end

function PANEL:open_panel(id)
  local panel = self.panels[id]

  if IsValid(self.cur_panel) then
    self.cur_panel:safe_remove()
  end

  if istable(panel) then
    if panel.permission and !PLAYER:can(panel.permission) then return end

    local sw, sh = self.sidebar:GetWide(), self.sidebar:GetTall()

    self.cur_panel = Theme.create_panel(panel.id, self, unpack(panel.arguments))
    self.cur_panel:SetPos(sw, 0)
    self.cur_panel:SetSize(self:GetWide() - sw, self:GetTall())
    self.cur_panel:SetParent(self)
    self.cur_panel.id = id

    if self.cur_panel.on_opened then
      self.cur_panel:on_opened(self, panel)
    end
  end
end

function PANEL:set_fullscreen(fullscreen)
  if fullscreen then
    self.sidebar:MoveTo(-self.sidebar:GetWide(), 0, 0.3)
    self:SetTitle('')

    self.back_button = vgui.Create('DButton', self)
    self.back_button:SetPos(0, 0)
    self.back_button:SetSize(100, 0)
    self.back_button:set_text('')

    self.back_button.Paint = function(btn, w, h)
      local font = Flux.fonts:GetSize(Theme.get_font('text_small'), 16)
      local font_size = util.font_size(font)

      FontAwesome:draw('fa-chevron-left', 6, 5, 14, Color(255, 255, 255))
      draw.SimpleText('Go Back', font, 24, 3 * (16 / font_size), Color(255, 255, 255))
    end

    self.back_button.DoClick = function(btn)
      self:set_fullscreen(false)
    end
  else
    self.sidebar:MoveTo(0, 0, 0.3)
    self:SetTitle('Admin')

    self.back_button:safe_remove()
  end
end

function PANEL:get_menu_size()
  return Font.scale(1280), Font.scale(900)
end

vgui.Register('fl_admin_panel', PANEL, 'fl_base_panel')
