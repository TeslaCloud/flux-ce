local PANEL = {}

function PANEL:Init()
  local w, h = ScrW() * 0.5, ScrH() * 0.5
  self:SetSize(w, h)
  self:MakePopup()
  self:set_draggable(true)
  self:set_title('ui.icon_editor.title')
  self:Center()

  local button_size = math.scale(48)

  self.model = vgui.create('DAdjustableModelPanel', self)
  self.model:SetSize(w * 0.5, h - button_size)
  self.model:Dock(LEFT)
  self.model:DockMargin(0, 0, 0, button_size + math.scale(8))
  self.model:SetModel('models/props_borealis/bluebarrel001.mdl')
  self.model:SetLookAt(Vector(0, 0, 0))
  self.model.LayoutEntity = function()
  end

  local x = math.scale_x(4)

  self.best = vgui.create('fl_button', self)
  self.best:SetSize(button_size, button_size)
  self.best:SetPos(x, h - button_size - math.scale(4))
  self.best:set_icon('fa-cube')
  self.best:set_centered(true)
  self.best:SetTooltip(t('ui.icon_editor.best'))
  self.best.DoClick = function()
    local entity = self.model:GetEntity()
    local pos = entity:GetPos()
    local cam_data = PositionSpawnIcon(entity, pos)

    if cam_data then
      self.model:SetCamPos(cam_data.origin)
      self.model:SetFOV(cam_data.fov)
      self.model:SetLookAng(cam_data.angles)
    end
  end

  x = x + button_size + math.scale_x(4)

  self.front = vgui.create('fl_button', self)
  self.front:SetSize(button_size, button_size)
  self.front:SetPos(x, h - button_size - math.scale(4))
  self.front:set_icon('fa-hand-point-up')
  self.front:set_centered(true)
  self.front:SetTooltip(t('ui.icon_editor.front'))
  self.front.DoClick = function()
    local entity = self.model:GetEntity()
    local pos = entity:GetPos()
    local cam_pos = pos + Vector(-200, 0, 0)

    self.model:SetCamPos(cam_pos)
    self.model:SetFOV(45)
    self.model:SetLookAng((cam_pos * -1):Angle())
  end

  x = x + button_size + math.scale_x(4)

  self.above = vgui.create('fl_button', self)
  self.above:SetSize(button_size, button_size)
  self.above:SetPos(x, h - button_size - math.scale(4))
  self.above:set_icon('fa-hand-point-down')
  self.above:set_centered(true)
  self.above:SetTooltip(t('ui.icon_editor.above'))
  self.above.DoClick = function()
    local entity = self.model:GetEntity()
    local pos = entity:GetPos()
    local cam_pos = pos + Vector(0, 0, 200)

    self.model:SetCamPos(cam_pos)
    self.model:SetFOV(45)
    self.model:SetLookAng((cam_pos * -1):Angle())
  end

  x = x + button_size + math.scale_x(4)

  self.right = vgui.create('fl_button', self)
  self.right:SetSize(button_size, button_size)
  self.right:SetPos(x, h - button_size - math.scale(4))
  self.right:set_icon('fa-hand-point-left')
  self.right:set_centered(true)
  self.right:SetTooltip(t('ui.icon_editor.right'))
  self.right.DoClick = function()
    local entity = self.model:GetEntity()
    local pos = entity:GetPos()
    local cam_pos = pos + Vector(0, 200, 0)

    self.model:SetCamPos(cam_pos)
    self.model:SetFOV(45)
    self.model:SetLookAng((cam_pos * -1):Angle())
  end

  x = x + button_size + math.scale_x(4)

  self.center = vgui.create('fl_button', self)
  self.center:SetSize(button_size, button_size)
  self.center:SetPos(x, h - button_size - math.scale(4))
  self.center:set_icon('fa-hand-pointer')
  self.center:set_centered(true)
  self.center:SetTooltip(t('ui.icon_editor.center'))
  self.center.DoClick = function()
    local entity = self.model:GetEntity()
    local pos = entity:GetPos()

    self.model:SetCamPos(pos)
    self.model:SetFOV(45)
    self.model:SetLookAng(Angle(0, -180, 0))
  end

  self.best:DoClick()

  self.preview = vgui.create('fl_base_panel', self)
  self.preview:Dock(FILL)
  self.preview:DockMargin(math.scale_x(4), 0, 0, 0)
  self.preview:DockPadding(math.scale_x(4), math.scale(4), math.scale_x(4), math.scale(4))
  self.preview.Paint = function(pnl, w, h)
    draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 100))
  end

  self.model_path = vgui.create('DTextEntry', self.preview)
  self.model_path:SetValue(self.model:GetModel())
  self.model_path:Dock(TOP)
  self.model_path.OnEnter = function(pnl)
    local model = pnl:GetValue()

    if model and model != '' then
      self.model:SetModel(model)
      self.item:rebuild()
    end
  end

  self.slot_size = vgui.create('DNumSlider', self.preview)
  self.slot_size:Dock(TOP)
  self.slot_size:SetText(t('ui.icon_editor.slot_size'))
  self.slot_size:SetMinMax(1, 512)
  self.slot_size:SetDecimals(0)
  self.slot_size:SetValue(64)
  self.slot_size.OnValueChanged = function(pnl, value)
    self.item:rebuild()
  end

  self.width = vgui.create('DNumSlider', self.preview)
  self.width:Dock(TOP)
  self.width:SetText(t('ui.icon_editor.width'))
  self.width:SetMinMax(1, 16)
  self.width:SetDecimals(0)
  self.width:SetValue(1)
  self.width.OnValueChanged = function(pnl, value)
    self.item:rebuild()
  end

  self.height = vgui.create('DNumSlider', self.preview)
  self.height:Dock(TOP)
  self.height:SetText(t('ui.icon_editor.height'))
  self.height:SetMinMax(1, 16)
  self.height:SetDecimals(0)
  self.height:SetValue(1)
  self.height.OnValueChanged = function(pnl, value)
    self.item:rebuild()
  end

  self.item_panel = vgui.create('fl_base_panel', self.preview)
  self.item_panel:Dock(FILL)
  self.item_panel.Paint = function(pnl, w, h)
    draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 100))
  end

  self.item = vgui.create('DModelPanel', self.item_panel)
  self.item:SetMouseInputEnabled(false)
  self.item.LayoutEntity = function()
  end
  self.item.PaintOver = function(pnl, w, h)
    surface.SetDrawColor(color_white)
    surface.DrawOutlinedRect(0, 0, w, h)
  end

  self.item.rebuild = function(pnl)
    local slot_size = math.scale(self.slot_size:GetValue())
    local padding = math.scale(2)
    local slot_w, slot_h = math.round(self.width:GetValue()), math.round(self.height:GetValue())
    local w, h = slot_w * (slot_size + padding) - padding, slot_h * (slot_size + padding) - padding

    pnl:SetModel(self.model:GetModel())
    pnl:SetCamPos(self.model:GetCamPos())
    pnl:SetFOV(self.model:GetFOV())
    pnl:SetLookAng(self.model:GetLookAng())
    pnl:SetSize(w, h)
    pnl:Center()
  end

  self.item:rebuild()

  timer.create('fl_icon_editor_update', 0.5, 0, function()
    if IsValid(self) and IsValid(self.model) then
      self.item:rebuild()
    else
      timer.destroy('fl_icon_editor_update')
    end
  end)

  self.copy = vgui.create('fl_button', self)
  self.copy:SetSize(button_size, button_size)
  self.copy:SetPos(w - button_size - math.scale_x(12), h - button_size - math.scale(12))
  self.copy:set_icon('fa-copy')
  self.copy:set_centered(true)
  self.copy:SetTooltip(t('ui.icon_editor.copy'))
  self.copy.DoClick = function()
    local cam_pos = self.model:GetCamPos()
    local cam_ang = self.model:GetLookAng()
    local str = "ITEM.model = '"..self.model:GetModel().."'\n"
      ..'ITEM.width = '..math.round(self.width:GetValue())..'\n'
      ..'ITEM.height = '..math.round(self.height:GetValue())..'\n'
      ..'ITEM.icon_data = {\n'
      ..'  origin = Vector('..math.round(cam_pos.x, 2)..', '..math.round(cam_pos.y, 2)..', '..math.round(cam_pos.z, 2)..'),\n'
      ..'  angles = Angle('..math.round(cam_ang.p, 2)..', '..math.round(cam_ang.y, 2)..', '..math.round(cam_ang.r, 2)..'),\n'
      ..'  fov    = '..math.round(self.model:GetFOV(), 2)..'\n'
      ..'}\n'

    SetClipboardText(str)

    PLAYER:notify('notification.icon_editor')
  end
end

vgui.Register('fl_icon_editor', PANEL, 'fl_frame')
