--- Shared hooks of the SrcdsProxy plugin: the Server Transfer Area mode of the Area Tool.
-- Staff draw a transfer area with it: left click adds points, right click creates the area,
-- reload removes the transfer area that is aimed at.

--- Builds the Server Transfer Area mode of the Area Tool.
-- @return [Map the mode definition, ready for mode_list:Add]
local function build_tool_mode()
  local mode = {}
  mode.title = t'tool.proxy_area.title'
  mode.area_type = SrcdsProxy.transfer_area_type
  mode.ClientConVar = {
    height = '512',
    proxy_backend = '',
    proxy_delay = tostring(SrcdsProxy.default_transfer_delay)
  }

  --- Starts a transfer area if needed and adds the aimed position as a vertex. A new area
  -- gets the server and the delay chosen in the tool and an ID of its own. Nothing is started
  -- without a server name, and the tool's owner is told so.
  -- @param tool [Tool the area tool]
  -- @param trace [Map trace result of the tool owner's aim]
  -- @return [Boolean true if a vertex was added, false if the server name is missing]
  function mode:OnLeftClick(tool, trace)
    if !tool.area then
      local backend = SrcdsProxy:server_name(tool:GetClientInfo('proxy_backend'))

      if !backend then
        if SERVER then
          tool:GetOwner():notify('error.proxy.area_no_backend')
        end

        return false
      end

      local id = SrcdsProxy:new_transfer_area_id(backend)
      local area = Areas.create(id, tonumber(tool:GetClientNumber('height')), { type = self.area_type })

      area.backend = backend
      area.delay = SrcdsProxy:transfer_delay(tool:GetClientNumber('proxy_delay'))

      tool.area = area
    end

    tool.area:add_vertex(trace.HitPos)

    return true
  end

  --- Registers the transfer area being built.
  -- @param tool [Tool the area tool]
  -- @return [Boolean true if an area was registered, nil otherwise]
  function mode:OnRightClick(tool)
    if tool.area then
      tool.area:register()
      tool.area = nil

      return true
    end
  end

  --- Adds the mode's server, delay and height controls to the tool's settings panel.
  -- @param panel [Panel the tool's control panel]
  function mode:BuildCPanel(panel)
    panel:AddControl('Header', { Description = t'tool.proxy_area.desc' })
    panel:AddControl('TextBox', { Label = t'tool.proxy_area.backend', Command = 'area_proxy_backend' })
    panel:AddControl('Slider', {
      Label = t'tool.proxy_area.delay',
      Command = 'area_proxy_delay',
      Type = 'Integer',
      Min = 0,
      Max = SrcdsProxy.max_transfer_delay
    })
    panel:AddControl('Slider', {
      Label = t'tool.proxy_area.height',
      Command = 'area_height',
      Type = 'Float',
      Min = -2048,
      Max = 2048
    })
  end

  return mode
end

--- Adds the Server Transfer Area mode to the Area Tool. When the list has such a mode
-- already, as it does after a code refresh, the mode takes its place and any other one is
-- removed, so that the indices of the other modes stay the same.
-- @param mode_list [Map the Area.tool_modes table; modes are added with mode_list:Add]
function SrcdsProxy:AddAreaToolModes(mode_list)
  mode_list:Add(build_tool_mode())

  local mode = table.remove(mode_list)
  local index

  for k = 1, #mode_list do
    if mode_list[k].area_type == self.transfer_area_type then
      index = k

      break
    end
  end

  if !index then
    table.insert(mode_list, mode)

    return
  end

  mode_list[index] = mode

  for k = #mode_list, index + 1, -1 do
    if mode_list[k].area_type == self.transfer_area_type then
      table.remove(mode_list, k)
    end
  end
end
