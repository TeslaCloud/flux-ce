PLUGIN:set_global('Area')

require_relative 'cl_plugin'
require_relative 'sv_plugin'

if !areas then
  require_relative 'lib/sh_areas'
end

--- Registers the 'areas' level design permission.
function Area:RegisterPermissions()
  Bolt:register_permission(
    'areas',
    'Manage areas',
    'Grants access to manage areas.',
    'permission.categories.level_design',
    'moderator'
  )
end

Area.tool_modes = {
  --- Adds a mode to the area tool and merges the mode's convars into the tool's convars.
  -- Meant to be called from the AddAreaToolModes hook as mode_list:Add(mode).
  -- ```
  -- function PLUGIN:AddAreaToolModes(mode_list)
  --   local mode = {}
  --   mode.title = 'Text Area'
  --   mode.area_type = 'textarea'
  --   mode.ClientConVar = { height = '512' }
  --
  --   function mode:OnLeftClick(tool, trace)
  --     tool.area = tool.area or Areas.create('my_area', 512, { type = self.area_type })
  --     tool.area:add_vertex(trace.HitPos)
  --
  --     return true
  --   end
  --
  --   mode_list:Add(mode)
  -- end
  -- ```
  -- @param list [Map the Area.tool_modes table the mode is appended to]
  -- @param data [Map mode definition: title, area_type, ClientConVar and the optional
  --   functions OnLeftClick(mode, tool, trace), OnRightClick(mode, tool, trace),
  --   OnReload(mode, tool, trace) and BuildCPanel(mode, panel). The default OnReload
  --   removes the area of that type under the trace]
  Add = function(list, data)
    local vars = data.ClientConVar or data.ConVars or data.ClientConVars or data.ConVar

    table.insert(list, {
      title = data.title or 'Unknown Mode',
      area_type = data.area_type or 'area',
      OnLeftClick = data.OnLeftClick,
      OnRightClick = data.OnRightClick,
      OnReload = data.OnReload or function(mode, tool, trace)
        local cur_time = CurTime()

        for k, v in pairs(Areas.all()) do
          if istable(v.polys) and isstring(v.type) and v.type == data.area_type then
            for k2, v2 in ipairs(v.polys) do
              local pos = trace.HitPos
              local z = pos.z + 16

              if z > v2[1].z and z < v.maxh then
                if util.vector_in_poly(pos, v2) then
                  Areas.remove(v.id)

                  return true
                end
              end
            end
          end
        end
      end,
      BuildCPanel = data.BuildCPanel,
      ClientConVar = vars
    })

    local tool = Flux.Tool:get('area')

    if IsValid(tool) and istable(vars) then
      table.Merge(tool.ClientConVar, vars)

      tool:CreateConVars()
    end
  end
}

--- Calls the AddAreaToolModes hook so that plugins can add their modes to the area tool.
function Area:OnSchemaLoaded()
  Plugin.call('AddAreaToolModes', self.tool_modes)
end

--- Adds the built-in 'Text Area' mode to the area tool.
-- @param mode_list [Map the Area.tool_modes table; modes are added with mode_list:Add]
function Area:AddAreaToolModes(mode_list)
  local mode = {}
  mode.title = 'Text Area'
  mode.area_type = 'textarea'
  mode.ClientConVar = mode.ClientConVar or {}
  mode.ClientConVar['height'] = '512'
  mode.ClientConVar['text'] = 'Sample Text'

  --- Starts a new text area if needed and adds the aimed position as a vertex.
  -- @param tool [Tool the area tool]
  -- @param trace [Map trace result of the tool owner's aim]
  -- @return [Boolean true if a vertex was added, false if the area text is invalid]
  function mode:OnLeftClick(tool, trace)
    local text = tostring(tool:GetClientInfo('text'))
    local height = tonumber(tool:GetClientNumber('height'))
    local id = text:to_id()

    if !id or id == '' then return false end

    if !tool.area then
      tool.area = Areas.create(id, height, { type = self.area_type })
      tool.area.text = text
    end

    tool.area:add_vertex(trace.HitPos)

    return true
  end

  --- Registers the text area being built.
  -- @param tool [Tool the area tool]
  -- @param trace [Map trace result of the tool owner's aim]
  -- @return [Boolean true if an area was registered, nil otherwise]
  function mode:OnRightClick(tool, trace)
    if tool.area then
      tool.area:register()
      tool.area = nil

      return true
    end
  end

  --- Adds the mode's text and height controls to the tool's settings panel.
  -- @param panel [Panel the tool's control panel]
  function mode:BuildCPanel(panel)
    panel:AddControl('Header', { Description = t'tool.area.desc' })
    panel:AddControl('TextBox', { Label = t'tool.area.text', Command = 'area_text', MaxLenth = '256' })
    panel:AddControl('Slider', {
      Label = t'tool.area.height',
      Command = 'area_height',
      Type = 'Float',
      Min = -2048,
      Max = 2048
    })
  end

  mode_list:Add(mode)
end

Areas.register_type(
  'textarea',
  'Text Area',
  'Displays text whenever a player enters the area.',
  Color(255, 0, 255),
  function(actor, area, has_entered, pos, cur_time)
    actor.text_areas = actor.text_areas or {}

    if has_entered then
      local area_data = actor.text_areas[area.id]

      if istable(area_data) and area_data.reset_time > cur_time then
        return
      end

      actor.text_areas[area.id] = { text = area.text, end_time = cur_time + 10, reset_time = cur_time + 20 }
    end
  end
)
