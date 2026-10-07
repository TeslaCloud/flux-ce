local PANEL = {}

--- Creates the root node of the condition tree and the buttons
-- that save and load condition presets.
function PANEL:Init()
  self:SetIndentSize(0)

  self.root = self:AddNode(t'ui.condition.right_click', 'icon16/key.png')
  self.root:SetExpanded(true)
  self.root.childs = {}
  self.root.DoRightClick = function(panel)
    self:node_options(panel, true, #panel.childs == 0)
  end

  self.save = vgui.create('fl_button', self)
  self.save:SetSize(math.scale(24), math.scale(24))
  self.save:set_icon('fa-save')
  self.save:set_centered(true)
  self.save.DoClick = function(btn)
    surface.play_sound('garrysmod/ui_click.wav')

    Derma_StringRequest(t'ui.condition.save.title',
    t'ui.condition.save.message',
    '',
    function(text)
      Data.save('conditions/'..text, self:get_conditions())

      surface.play_sound('garrysmod/ui_click.wav')
    end,
    function(text)
      surface.play_sound('garrysmod/ui_click.wav')
    end)
  end

  self.load = vgui.create('fl_button', self)
  self.load:SetSize(math.scale(24), math.scale(24))
  self.load:set_icon('fa-folder-open')
  self.load:set_centered(true)
  self.load.DoClick = function(btn)
    surface.play_sound('garrysmod/ui_click.wav')

    local frame = vgui.create('DFrame')
    frame:SetSize(ScrW() * 0.2, ScrH() * 0.2)
    frame:SetTitle(t'ui.condition.load.title')
    frame:Center()
    frame:MakePopup()

    local list = vgui.create('DListView', frame)
    list:Dock(FILL)
    list:AddColumn(t'ui.condition.load.column')

    for k, v in pairs(Data.get_files('conditions')) do
      list:AddLine(v)
    end

    list.OnRowSelected = function(lst, index, line)
      surface.play_sound('garrysmod/ui_click.wav')

      self:clear()
      self:set_conditions(self.root, Data.load('conditions/'..line:GetColumnText(1)))

      frame:safe_remove()
    end
  end
end

--- Moves the save and load buttons to the top right corner of the panel.
-- Should be called after the panel has been resized.
function PANEL:update()
  self.save:SetPos(self:GetWide() - self.save:GetWide() - 2, 2)
  self.load:SetPos(self:GetWide() - self.save:GetWide() * 2 - 4, 2)
end

--- Opens the context menu of a node: adding a child condition and, for condition nodes,
-- setting the parameter and the operator or deleting the condition.
-- @param panel [Panel the tree node that was right-clicked]
-- @param root=nil [Boolean whether the node is the root node, currently unused]
-- @param first=nil [Boolean whether the node has no child conditions, currently unused]
function PANEL:node_options(panel, root, first)
  local menu = DermaMenu()

  local sub_menu = menu:AddSubMenu(t'ui.condition.add_condition')

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
      menu:AddOption(t'ui.condition.set_parameter', function()
        data.set_parameters(id, data, panel, menu, self)
      end)
    end

    if data.set_operator then
      menu:AddOption(t'ui.condition.set_operator', function()
        if isfunction(data.set_operator) then
          data.set_operator(id, data, panel, menu)
        elseif isstring(data.set_operator) then
          local selector = vgui.create('fl_selector')
          selector:set_title(t(data.name))
          selector:set_text(t'ui.condition.select_operator')
          selector:set_value(t'ui.condition.operators')

          for k, v in pairs(util['get_'..data.set_operator..'_operators']()) do
            selector:add_choice(t('operator.'..k)..' ('..v..')', function()
              panel.data.operator = k

              panel.update()
            end)
          end
        end
      end)
    end

    menu:AddOption(t'ui.condition.delete', function()
      panel:safe_remove()
    end)
  end

  menu:Open()
end

--- Adds a node of the specified condition type under the parent node.
-- @param parent [Panel tree node to add the condition to]
-- @param id [String id of a registered condition]
-- @param data=nil [Hash parameters of the condition, empty when omitted]
-- @return [Panel the created node]
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
          args[k] = t'ui.condition.select_operator'
        else
          args[k] = t'ui.condition.select_parameter'
        end
      end
    end

    node:SetText(t(condition_data.text, args))
  end

  node.update()

  table.insert(parent.childs, node)

  return node
end

--- Collects the condition tree into a table that can be networked, saved
-- and passed to Conditions:check.
-- @param panel=nil [Panel node to start from, the root node when omitted]
-- @return [Array condition nodes, each a Hash with id, data and childs]
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

--- Recreates the nodes of a condition tree under the parent node.
-- @param parent [Panel tree node to add the conditions to, e.g. the root node]
-- @param conditions [Array condition nodes as returned by get_conditions]
function PANEL:set_conditions(parent, conditions)
  for k, v in pairs(conditions) do
    local data = Conditions:get_all()[v.id]
    local node = self:add_condition(parent, v.id, v.data)

    if v.childs then
      self:set_conditions(node, v.childs)
    end
  end
end

--- Removes all condition nodes from the tree, leaving only the root node.
function PANEL:clear()
  for k, v in pairs(self.root.childs) do
    v:safe_remove()
  end

  self.root.childs = {}
end

--- Opens a selector popup and calls the callback once for every choice right away,
-- so that it can add the choice to the selector.
-- ```
-- parent:create_selector(data.name, 'condition.role.message', 'condition.roles',
--   Bolt:get_roles(), function(selector, role)
--     selector:add_choice(t(role.name), function()
--       panel.data.role = role.id
--
--       panel.update()
--     end)
--   end)
-- ```
-- @param title [String title phrase]
-- @param message [String message phrase]
-- @param default_value [String phrase of the text that is displayed before a choice is made]
-- @param choices [Array/Hash values to choose from]
-- @param callback [Function called as callback(selector, choice) for every choice]
-- @return [Panel the created fl_selector panel]
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
