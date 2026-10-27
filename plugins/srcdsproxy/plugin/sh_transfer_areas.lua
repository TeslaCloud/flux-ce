--- Shared side of the server transfer areas of the SrcdsProxy plugin: the `proxy_transfer`
-- area type and its mode of the Area Tool. A transfer area keeps the name of a server of the
-- proxy network in its `backend` field and a number of seconds in its `delay` field; a player
-- who stays in it for that long is moved to that server. Staff draw one with the Server
-- Transfer Area mode: left click adds points, right click creates the area, reload removes
-- the transfer area that is aimed at.

SrcdsProxy.transfer_area_type = 'proxy_transfer'
SrcdsProxy.default_transfer_delay = 5
SrcdsProxy.max_transfer_delay = 300

--- Turns what a player typed as the name of a server of the network into one word that is
-- safe to pass to `Proxy.transfer`: whitespace, semicolons and double quotes are removed.
-- @param text [String server name as typed]
-- @return [String the server name, or nil if nothing is left of it]
function SrcdsProxy:server_name(text)
  local name = tostring(text or ''):gsub('[%s;"]', '')

  if name == '' then
    return
  end

  return name
end

--- Turns a value into the delay of a transfer area: a number of seconds from 0 to
-- `SrcdsProxy.max_transfer_delay`.
-- @param value [Any delay as a number or a text]
-- @return [Number the delay, `SrcdsProxy.default_transfer_delay` if the value is no number]
function SrcdsProxy:transfer_delay(value)
  return math.Clamp(tonumber(value) or self.default_transfer_delay, 0, self.max_transfer_delay)
end

--- Finds an ID for a new transfer area that moves players to a server: the server's name
-- made into an ID, with the first number that no area has yet. Both realms have the same
-- areas, so they find the same ID.
-- @param backend [String server name, as returned by `SrcdsProxy:server_name`]
-- @return [String]
function SrcdsProxy:new_transfer_area_id(backend)
  local base = 'proxy_'..backend:to_id()
  local stored = Areas.all()
  local count = 1

  while stored[base..'_'..count] != nil do
    count = count + 1
  end

  return base..'_'..count
end

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

Areas.register_type(
  SrcdsProxy.transfer_area_type,
  'Server Transfer Area',
  'Moves the players who stay in the area for its delay to another server of the proxy network.',
  Color(0, 170, 255),
  function(actor, area, has_entered)
    if CLIENT or !has_entered then return end

    SrcdsProxy:enter_transfer_area(actor, area)
  end
)
