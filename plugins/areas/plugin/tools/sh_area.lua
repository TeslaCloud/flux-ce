--- The Area Tool creates and removes areas. Left click, right click and reload are passed on
-- to the selected tool mode; modes are added by plugins through the `AddAreaToolModes`
-- hook and picked from the list in the tool's settings panel. The tool requires the
-- `areas` permission, which each of its actions checks as well.

TOOL.Category = 'Flux'
TOOL.Name = 'Area Tool'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'manage_areas'

TOOL.ClientConVar['mode'] = '1'

--- Passes the click to the OnLeftClick handler of the selected area tool mode.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean the result of the mode's handler, true if the mode has no handler,
--   nil if the owner lacks the 'manage_areas' permission]
function TOOL:LeftClick(trace)
  if !self:GetOwner():can('manage_areas') then return end

  local mode_table = self:get_area_mode()

  if istable(mode_table) and isfunction(mode_table.OnLeftClick) then
    return mode_table:OnLeftClick(self, trace)
  end

  return true
end

--- Passes the click to the OnRightClick handler of the selected area tool mode.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean the result of the mode's handler, true if the mode has no handler,
--   nil if the owner lacks the 'manage_areas' permission]
function TOOL:RightClick(trace)
  if !self:GetOwner():can('manage_areas') then return end

  local mode_table = self:get_area_mode()

  if istable(mode_table) and isfunction(mode_table.OnRightClick) then
    return mode_table:OnRightClick(self, trace)
  end

  return true
end

--- Passes the reload to the OnReload handler of the selected area tool mode.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean the result of the mode's handler, true if the mode has no handler,
--   nil if the owner lacks the 'manage_areas' permission]
function TOOL:Reload(trace)
  if !self:GetOwner():can('manage_areas') then return end

  local mode_table = self:get_area_mode()

  if istable(mode_table) and isfunction(mode_table.OnReload) then
    return mode_table:OnReload(self, trace)
  end

  return true
end

--- Returns the area tool mode selected with the 'mode' convar.
-- @return [Map the mode table, or nil if there is no mode with that index]
function TOOL:get_area_mode()
  local mode = self:GetClientNumber('mode')

  return Area.tool_modes[mode]
end

if CLIENT then
  local function build_cpanel(panel)
    local mode_list = Area.tool_modes

    panel:ClearControls()

    local mode = PLAYER:GetInfoNum('area_mode', 0)
    local mode_view = vgui.Create('DListView')

    mode_view:SetSize(30, DermaScale.scale(90))
    mode_view:AddColumn('Tool Mode')
    mode_view:SetMultiSelect(false)

    --- Switches the area tool to the selected mode.
    -- @param id [Number index of the selected row]
    -- @param _line [Panel the selected row]
    function mode_view:OnRowSelected(id, _line)
      if mode != id then
        RunConsoleCommand('area_setmode', id)
      end
    end

    for mode_id, mode_data in ipairs(mode_list) do
      if mode == mode_id then
        mode_view:AddLine(' '..mode_id..' >> '..mode_data.title)
      else
        mode_view:AddLine(' '..mode_id..'  '..mode_data.title)
      end
    end

    mode_view:SortByColumn(1)

    panel:AddItem(mode_view)

    local mode_table = mode_list[mode]

    if istable(mode_table) and isfunction(mode_table.BuildCPanel) then
      mode_table:BuildCPanel(panel)
    end
  end

  --- Builds the tool's settings panel: the list of modes and the controls of the
  -- selected mode.
  -- @param panel [Panel the tool's control panel]
  function TOOL.BuildCPanel(panel)
    build_cpanel(panel)
  end

  concommand.Add('area_setmode', function(_client, _command, args)
    RunConsoleCommand('area_mode', args[1])

    timer.Simple(0.05, function()
      local panel = controlpanel.Get('area')

      if !panel then return end

      build_cpanel(panel)
    end)
  end)
end
