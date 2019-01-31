local PANEL = {}

function PANEL:Init()
  self:SetIndentSize(0)

  self.root = self:AddNode(t'conditions.right_click', 'icon16/key.png')
  self.root:SetExpanded(true)
  self.root.childs = {}
  self.root.DoRightClick = function(panel)
    self:node_options(panel, true, #panel.childs == 0)
  end

  self.save = vgui.create('fl_button', self)
  self.save:SetSize(font.scale(24), font.scale(24))
  self.save:set_icon('fa-save')
  self.save:set_centered(true)
  self.save.DoClick = function(btn)
    surface.play_sound('garrysmod/ui_click.wav')

    Derma_StringRequest(t'conditions.save.title',
    t'conditions.save.message',
    '',
    function(text)
      data.save('conditions/'..text, self:get_conditions())

      surface.play_sound('garrysmod/ui_click.wav')
    end,
    function(text)
      surface.play_sound('garrysmod/ui_click.wav')
    end)
  end

  self.load = vgui.create('fl_button', self)
  self.load:SetSize(font.scale(24), font.scale(24))
  self.load:set_icon('fa-folder-o')
  self.load:set_centered(true)
  self.load.DoClick = function(btn)
    surface.play_sound('garrysmod/ui_click.wav')

    local frame = vgui.create('DFrame')
    frame:SetSize(ScrW() * 0.2, ScrH() * 0.2)
    frame:SetTitle(t'conditions.load.title')
    frame:Center()
    frame:MakePopup()

    local list = vgui.create('DListView', frame)
    list:Dock(FILL)
    list:AddColumn(t'conditions.load.column')

    for k, v in pairs(data.get_files('conditions')) do
      list:AddLine(v)
    end

    list.OnRowSelected = function(lst, index, line)
      surface.play_sound('garrysmod/ui_click.wav')

      self:clear()
      self:set_conditions(self.root, data.load('conditions/'..line:GetColumnText(1)))

      frame:safe_remove()
    end
  end
end

function PANEL:update()
  self.save:SetPos(self:GetWide() - self.save:GetWide() - 2, 2)
  self.load:SetPos(self:GetWide() - self.save:GetWide() * 2 - 4, 2)
end

function PANEL:node_options(panel, root, first)
  local menu = DermaMenu()

  local sub_menu = menu:AddSubMenu(t'conditions.add_condition')
  
  for k, v in pairs(Conditions:get_all()) do
    sub_menu:AddOption(t(v.name), function()
      self:add_condition(panel, k)
    end):SetIcon(v.icon)
  end

  local id = panel.id

  if id then
    local data = Conditions:get_all()[id]

    menu:AddSpacer()

    if data.set_parameters then
      menu:AddOption(t'conditions.set_parameter', function()
        data.set_parameters(id, data, panel, menu, self)
      end)
    end

    if data.set_operator then
      menu:AddOption(t'conditions.set_operator', function()
        if isfunction(data.set_operator) then
          data.set_operator(id, data, panel, menu)
        elseif isstring(data.set_operator) then
          local selector = vgui.create('fl_selector')
          selector:set_title(t(data.name))
          selector:set_text(t'conditions.select_operator')
          selector:set_value(t'conditions.operators')

          for k, v in pairs(util['get_'..data.set_operator..'_operators']()) do
            selector:add_choice(t('operators.'..k)..' ('..v..')', function()
              panel.data.operator = k
        
              panel.update()
            end)
          end
        end
      end)
    end

    menu:AddOption(t'conditions.delete', function()
      panel:safe_remove()
    end)
  end

  menu:Open()
end

function PANEL:add_condition(parent, id, data)
  local condition_data = Conditions:get_all()[id]
  local node = parent:AddNode('', condition_data.icon)
  node:SetExpanded(true)
  node.id = id
  node.data = data or {}
  node.childs = {}
  node.DoRightClick = function()
    self:node_options(node)
  end

  node.update = function()
    local args = {}

    for k, v in pairs(condition_data.get_args(node, condition_data)) do
      if v != '' then
        args[k] = t(v)
      else
        if k == 1 then
          args[k] = t'conditions.select_operator'
        else
          args[k] = t'conditions.select_parameter'
        end
      end
    end
  
    node:SetText(t(condition_data.text, args))
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
    local data = Conditions:get_all()[v.id]
    local node = self:add_condition(parent, v.id, v.data)

    if v.childs then
      self:set_conditions(node, v.childs)
    end
  end
end

function PANEL:clear()
  for k, v in pairs(self.root.childs) do
    v:safe_remove()
  end

  self.root.childs = {}
end

function PANEL:create_selector(title, message, default_value, choices, callback)
  local selector = vgui.create('fl_selector')
  selector:set_title(t(title))
  selector:set_text(t(message))
  selector:set_value(t(default_value))

  for k, v in pairs(choices) do
    callback(selector, v)
  end

  return selector
end

vgui.register('fl_conditions', PANEL, 'DTree')
