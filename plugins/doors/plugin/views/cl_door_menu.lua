local PANEL = {}

function PANEL:Init()
  self:SetSize(ScrW() * 0.25, ScrH() * 0.4)
  self:Center()
  self:SetTitle(t'ui.door.title')

  self:MakePopup()

  self.door_data = {}

  self.properties = vgui.create('DProperties', self)
  self.properties:SetSize(self:GetWide() - 10, self:GetTall() * 0.5)
  self.properties:Dock(TOP)

  self.conditions = vgui.create('fl_conditions', self)
  self.conditions:SetSize(self:GetWide() - 10, self:GetTall() - self.properties:GetTall() - 34)
  self.conditions:Dock(TOP)
  self.conditions:update()
end

function PANEL:OnKeyCodePressed(key)
  if key == KEY_F3 then
    self:safe_remove()
  end
end

function PANEL:OnRemove()
  CloseDermaMenus()

  for k, v in pairs(self:get_door_data()) do
    Cable.send('fl_send_door_data', self:get_door(), k, v)
  end

  Cable.send('fl_send_door_conditions', self:get_door(), self.conditions:get_conditions())
end

function PANEL:set_door(entity, conditions)
  self.door = entity

  for k, v in pairs(Doors.properties) do
    if v.create_panel then
      local value = v.get_save_data(entity)

      local row = v.create_panel(entity, self)

      if row then
        row:SetValue(value)
        row.DataChanged = function(pnl, data)
          self.door_data[k] = data
        end
      end
    end
  end

  if conditions then
    self.conditions:set_conditions(self.conditions.root, conditions)
  end
end

function PANEL:get_door()
  return self.door
end

function PANEL:get_door_data()
  return self.door_data
end

vgui.register('fl_door_menu', PANEL, 'DFrame')
