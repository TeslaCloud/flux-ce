local PANEL = {}

--- Sets up the frame with the list of door properties and the conditions editor.
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

--- Closes the menu when F3 is pressed.
-- @param key [Number key code]
function PANEL:OnKeyCodePressed(key)
  if key == KEY_F3 then
    self:safe_remove()
  end
end

--- Sends the changed properties and the conditions of the door to the server.
function PANEL:OnRemove()
  CloseDermaMenus()

  for k, v in pairs(self:get_door_data()) do
    Cable.send('fl_send_door_data', self:get_door(), k, v)
  end

  Cable.send('fl_send_door_conditions', self:get_door(), self.conditions:get_conditions())
end

--- Sets the door to edit, creates the rows for its properties
-- and fills the conditions editor.
-- @param entity [Entity the door]
-- @param conditions=nil [Array condition nodes that are currently set on the door]
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

--- Returns the door that is being edited.
-- @return [Entity the door, or nil if it has not been set yet]
function PANEL:get_door()
  return self.door
end

--- Returns the properties that were changed in the menu.
-- @return [Hash changed values keyed by property id]
function PANEL:get_door_data()
  return self.door_data
end

vgui.register('fl_door_menu', PANEL, 'DFrame')
