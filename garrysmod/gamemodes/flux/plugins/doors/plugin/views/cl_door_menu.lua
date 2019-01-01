local PANEL = {}

function PANEL:Init()
  self:SetSize(ScrW() * 0.25, ScrH() * 0.4)
  self:Center()
  self:SetTitle(t'doors.title')

  self:MakePopup()

  self.door_data = {}

  self.properties = vgui.create('DProperties', self)
  self.properties:SetSize(0, self:GetTall() * 0.5)
  self.properties:Dock(TOP)

  self.conditions = vgui.create('DTree', self)
  self.conditions:SetSize(0, self:GetTall() - self.properties:GetTall() - 34)
  self.conditions:Dock(TOP)

  self.conditions.root = self.conditions:AddNode('Press RMB here to add new condition.', 'icon16/key.png')
  self.conditions.root:SetExpanded(true)
  self.conditions.root.DoRightClick = function(panel)
    local menu = DermaMenu()

    local sub_menu = menu:AddSubMenu('Add condition')
    
    for k, v in pairs(Doors.conditions) do
      sub_menu:AddOption(v.name, function()
        panel:AddNode(v.text, v.icon)
      end)
    end

    menu:Open()
  end

end

function PANEL:OnKeyCodePressed(key)
  if key == KEY_F3 then
    self:safe_remove()
  end
end

function PANEL:OnRemove()
  for k, v in pairs(self:get_door_data()) do
    cable.send('fl_send_door_data', self:get_door(), k, v)
  end
end

function PANEL:set_door(entity)
  self.door = entity

  for k, v in pairs(Doors.properties) do
    if v.create_panel then
      local value = v.get_save_data(entity)

      local row = v.create_panel(entity, self)
      row:SetValue(value)
      row.DataChanged = function(p, data)
        self.door_data[k] = data
      end
    end
  end
end

function PANEL:get_door()
  return self.door
end

function PANEL:get_door_data()
  return self.door_data
end

vgui.register('fl_door_menu', PANEL, 'DFrame')

