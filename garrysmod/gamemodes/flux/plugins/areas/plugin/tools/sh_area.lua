TOOL.Category = 'Flux'
TOOL.Name = 'Area Tool'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'areas'

TOOL.ClientConVar['mode'] = '1'

function TOOL:LeftClick(trace)
  local player = self:GetOwner()

  if !player:can('area_tool') then return end

  local mode = self:GetClientNumber('mode')
  local mode_table = Area.tool_modes[mode]

  if istable(mode_table) and isfunction(mode_table.OnLeftClick) then
    return mode_table:OnLeftClick(self, trace)
  end

  return true
end

function TOOL:RightClick(trace)
  local player = self:GetOwner()

  if !player:can('area_tool') then return end

  local mode = self:GetClientNumber('mode')
  local mode_table = Area.tool_modes[mode]

  if istable(mode_table) and isfunction(mode_table.OnRightClick) then
    return mode_table:OnRightClick(self, trace)
  end

  return true
end

function TOOL:Reload(trace)
  local player = self:GetOwner()

  if !player:can('area_tool') then return end

  local mode = self:GetClientNumber('mode')
  local mode_table = Area.tool_modes[mode]

  if istable(mode_table) and isfunction(mode_table.OnReload) then
    return mode_table:OnReload(self, trace)
  end

  return true
end

function TOOL:GetAreaMode()
  local mode = self:GetClientNumber('mode')

  return Area.tool_modes[mode]
end

if CLIENT then
  -- A function to add the controls for the tool in the tool menu.
  local function BuildCPanel(panel)
    local mode_list = Area.tool_modes

    panel:ClearControls()

    local mode = PLAYER:GetInfoNum('area_mode', 0)
    local list = vgui.Create('DListView')

    list:SetSize(30, 90)
    list:AddColumn('Tool Mode')
    list:SetMultiSelect(false)

    function list:OnRowSelected(id, line)
      if mode != id then
        RunConsoleCommand('area_setmode', id)
      end
    end

    for k, v in ipairs(mode_list) do
      if mode == k then
        list:AddLine(' '..k..' >> '..v.title)
      else
        list:AddLine(' '..k..'  '..v.title)
      end
    end

    list:SortByColumn(1)

    panel:AddItem(list)

    local mode_table = mode_list[mode]

    if istable(mode_table) and isfunction(mode_table.BuildCPanel) then
      mode_table:BuildCPanel(panel)
    end
  end

  -- Called to build the controls in the tool menu.
  function TOOL.BuildCPanel(panel)
    BuildCPanel(panel)
  end

  concommand.Add('area_setmode', function(player, command, args)
    RunConsoleCommand('area_mode', args[1])

    timer.Simple(0.05, function()
      local panel = controlpanel.Get('area')

      if !panel then return end

      BuildCPanel(panel)
    end)
  end)
end
/*
function TOOL.BuildCPanel(CPanel)
  local types = areas.get_types()
  local options = {}

  for k, v in pairs(types) do
    options[v.name] = {['area_areatype'] = k}
  end

  CPanel:AddControl('Header', { Description = 'tool.area.desc' })

  local control_presets = CPanel:AddControl('ComboBox', { MenuButton = 1, Folder = 'areatype', Options = options, CVars = {'area_areatype'} })
  control_presets.Button:SetVisible(false)
  control_presets.DropDown:SetValue('Simple Area')

  CPanel:AddControl('TextBox', { Label = 'tool.area.text', Command = 'area_uniqueid', MaxLenth = '20' })
  CPanel:AddControl('Slider', { Label = 'tool.area.height', Command = 'area_height', Type = 'Float', Min = -2048, Max = 2048 })
end
*/
