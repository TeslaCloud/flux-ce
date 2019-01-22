local PANEL = {}

function PANEL:Init()
  self:SetIndentSize(0)

  self.root = self:AddNode(t'conditions.right_click', 'icon16/key.png')
  self.root:SetExpanded(true)
  self.root.childs = {}
  self.root.DoRightClick = function(panel)
    self:node_options(panel, true, #panel.childs == 0)
  end
end

function PANEL:node_options(panel, root, first)
  local menu = DermaMenu()

  local sub_menu = menu:AddSubMenu(t'conditions.add_condition')
  
  for k, v in pairs(condition) do
    sub_menu:AddOption(v.name, function()
      self:add_condition(panel, k)
    end):SetIcon(v.icon)
  end

  local id = panel.id

  if id then
    local data = condition[id]

    menu:AddSpacer()

    if data.set_parameters then
      menu:AddOption(t'conditions.set_parameter', function()
        data.set_parameters(id, data, panel, menu)
      end)
    end

    if data.set_operator then
      menu:AddOption(t'conditions.set_operator', function()
        if isfunction(data.set_operator) then
          data.set_operator(id, data, panel, menu)
        elseif isstring(data.set_operator) then
          local selector = vgui.create('fl_selector')
          selector:set_title(t(data.name))
          selector:set_text(t'condition.select_operator')
          selector:set_value(t'conditions.operators')
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

    menu:AddOption(t'conditions.delete', function()
      panel:safe_remove()
    end)
  end

  menu:Open()
end

function PANEL:add_condition(parent, id, data)
  local condition_data = condition[id]
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
    local data = condition[v.id]
    local node = self:add_condition(parent, v.id, v.data)

    if v.childs then
      self:set_conditions(node, v.childs)
    end
  end
end

function PANEL:create_selector(title, message, default_value, choices, callback)
  local selector = vgui.create('fl_selector')
  selector:set_title(t(title))
  selector:set_text(t(message))
  selector:set_value(t(default_value))
  selector:Center()

  for k, v in pairs(choices) do
    callback(selector, v)
  end

  return selector
end

vgui.register('fl_conditions', PANEL, 'DTree')
