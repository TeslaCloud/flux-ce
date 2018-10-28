PLUGIN:set_global('flAreas')

util.include('cl_plugin.lua')
util.include('sv_plugin.lua')

if !areas then
  util.include('lib/sh_areas.lua')
end

flAreas.tool_modes = {
  Add = function(list, data)
    local vars = data.ClientConVar or data.ConVars or data.ClientConVars or data.ConVar

    table.insert(list, {
      title = data.title or 'Unknown Mode',
      area_type = data.area_type or 'area',
      OnLeftClick = data.OnLeftClick,
      OnRightClick = data.OnRightClick,
      OnReload = data.OnReload or function(mode, tool, trace)
        local cur_time = CurTime()

        for k, v in pairs(areas.GetAll()) do
          if istable(v.polys) and isstring(v.type) and v.type == data.area_type then
            for k2, v2 in ipairs(v.polys) do
              local pos = trace.HitPos
              local z = pos.z + 16

              if z > v2[1].z and z < v.maxh then
                if util.vector_in_poly(pos, v2) then
                  areas.Remove(v.id)

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

    local tool = fl.tool:get('area')

    if IsValid(tool) and istable(vars) then
      table.merge(tool.ClientConVar, vars)

      tool:CreateConVars()
    end
  end
}

function flAreas:OnSchemaLoaded()
  plugin.call('AddAreaToolModes', self.tool_modes)
end

function flAreas:AddAreaToolModes(modeList)
  local mode = {}
  mode.title = 'Text Area'
  mode.area_type = 'textarea'
  mode.ClientConVar = mode.ClientConVar or {}
  mode.ClientConVar['height'] = '512'
  mode.ClientConVar['text'] = 'Sample Text'

  function mode:OnLeftClick(tool, trace)
    local text = tostring(tool:GetClientInfo('text'))
    local height = tonumber(tool:GetClientNumber('height'))
    local id = text:to_id()

    if !id or id == '' then return false end

    if !tool.area then
      tool.area = areas.Create(id, height, { type = self.area_type })
      tool.area.text = text
    end

    tool.area:AddVertex(trace.HitPos)

    return true
  end

  function mode:OnRightClick(tool, trace)
    if tool.area then
      tool.area:register()
      tool.area = nil

      return true
    end
  end

  function mode:BuildCPanel(panel)
    panel:AddControl('Header', { Description = 'tool.area.desc' })
    panel:AddControl('TextBox', { Label = 'tool.area.text', Command = 'area_text', MaxLenth = '256' })
    panel:AddControl('Slider', { Label = 'tool.area.height', Command = 'area_height', Type = 'Float', Min = -2048, Max = 2048 })
  end

  modeList:Add(mode)
end

areas.RegisterType('textarea', 'Text Area', 'Displays text whenever player enters the area.', Color(255, 0, 255), function(player, area, has_entered, pos, cur_time)
  player.text_areas = player.text_areas or {}

  if has_entered then
    local area_data = player.text_areas[area.id]

    if istable(area_data) and area_data.reset_time > cur_time then
      return
    end

    player.text_areas[area.id] = {text = area.text, end_time = cur_time + 10, reset_time = cur_time + 20}
  end
end)
