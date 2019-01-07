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

  self.conditions = vgui.create('fl_door_conditions', self)
  self.conditions:SetSize(0, self:GetTall() - self.properties:GetTall() - 34)
  self.conditions:Dock(TOP)
end

function PANEL:OnKeyCodePressed(key)
  if key == KEY_F3 then
    self:safe_remove()
  end
end

function PANEL:OnRemove()
  CloseDermaMenus()

  for k, v in pairs(self:get_door_data()) do
    cable.send('fl_send_door_data', self:get_door(), k, v)
  end

  cable.send('fl_send_door_conditions', self:get_door(), self.conditions:get_conditions())
end

function PANEL:set_door(entity, conditions)
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

PANEL = {}

function PANEL:Init()
  self:SetIndentSize(0)

  self.root = self:AddNode(t'doors.right_click', 'icon16/key.png')
  self.root:SetExpanded(true)
  self.root.childs = {}
  self.root.DoRightClick = function(panel)
    self:node_options(panel, true, #panel.childs == 0)
  end
end

function PANEL:node_options(panel, root, first)
  local menu = DermaMenu()

  local sub_menu = menu:AddSubMenu(t'doors.add_condition')
  
  for k, v in pairs(Doors.conditions) do
    sub_menu:AddOption(v.name, function()
      self:add_condition(panel, k)
    end):SetIcon(v.icon)
  end

  local id = panel.id

  if id then
    local data = Doors.conditions[id]

    menu:AddSpacer()

    if data.set_parameters then
      menu:AddOption(t'doors.set_parameter', function()
        data.set_parameters(id, data, panel, menu)
      end)
    end

    if data.set_operator then
      menu:AddOption(t'doors.set_operator', function()
        if isfunction(data.set_operator) then
          data.set_operator(id, data, panel, menu)
        elseif isstring(data.set_operator) then
          local selector = vgui.create('fl_selector')
          selector:set_title(t(data.name))
          selector:set_text(t'doors.select_operator')
          selector:set_value(t'doors.operators')
          selector:Center()

          for k, v in pairs(util['get_'..data.set_operator..'_operators']()) do
            selector:add_choice(t('operators.'..k)..' ('..v..')', function()
              panel.data.operator = k
        
              panel.update()
            end)
          end
        end
      end)
    end

    menu:AddOption(t'doors.delete', function()
      panel:safe_remove()
    end)
  end

  menu:Open()
end

function PANEL:add_condition(parent, id, data)
  local condition_data = Doors.conditions[id]
  local node = parent:AddNode('', condition_data.icon)
  node:SetExpanded(true)
  node.id = id
  node.data = data or {}
  node.childs = {}
  node.DoRightClick = function()
    self:node_options(node)
  end

  node.update = function()
    node:SetText(condition_data.format(node, condition_data))
  end

  node.update()

  table.insert(parent.childs, node)

  return node
end

function PANEL:get_conditions(panel)
  if !IsValid(panel) then panel = self.root end

  local conditions = {}

  for k, v in pairs(panel.childs) do
    if !IsValid(v) then continue end

    local node = {
      id = v.id,
      data = v.data
    }

    if v.childs then
      node.childs = self:get_conditions(v)
    end

    table.insert(conditions, node)
  end

  return conditions
end

function PANEL:set_conditions(parent, conditions)
  for k, v in pairs(conditions) do
    local data = Doors.conditions[v.id]
    local node = self:add_condition(parent, v.id, v.data)

    if v.childs then
      self:set_conditions(node, v.childs)
    end
  end
end

vgui.register('fl_door_conditions', PANEL, 'DTree')