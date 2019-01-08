PLUGIN:set_global('Attributes')

util.include('sv_hooks.lua')

function Attributes:PluginIncludeFolder(extra, folder)
  for k, v in pairs(attributes.types) do
    if extra == k then
      attributes.include_type(k, v, folder..'/'..k..'/')

      return true
    end
  end
end

function Attributes:OnPluginsLoaded()
  if Doors then
    Doors:register_condition('attribute', {
      name = t'doors.conditions.attribute.name',
      text = t'doors.conditions.attribute.text'..' %s %s %s',
      format = function(panel, data)
        local panel_data = panel.data
        local attribute_name = t'doors.select_parameter'
        local operator = util.operator_to_symbol(panel_data.operator) or t'doors.select_operator'
        local attribute_value = panel_data.attribute_value or t'doors.select_parameter'

        if panel_data.attribute then
          attribute_name = attributes.find_by_id(panel_data.attribute).name
        end

        return string.format(data.text, t(attribute_name), operator, attribute_value)
      end,
      icon = 'icon16/chart_bar.png',
      check = function(player, entity, data)
        if !data.operator or !data.attribute or !data.attribute_value then return false end

        return util.process_operator(data.operator, player:get_attribute(data.attribute), data.attribute_value)
      end,
      set_parameters = function(id, data, panel, menu)
        local selector = vgui.create('fl_selector')
        selector:set_title(t(data.name))
        selector:set_text(t'doors.conditions.attribute.message1')
        selector:set_value(t'doors.attributes')
        selector:Center()

        for k, v in pairs(attributes.get_stored()) do
          selector:add_choice(t(v.name), function()
            panel.data.attribute = v.attr_id
      
            panel.update()

            Derma_StringRequest(
              t(data.name),
              t'doors.conditions.attribute.message2',
              '',
              function(text)
                panel.data.attribute_value = tonumber(text)
        
                panel.update()
              end
            )
          end)
        end
      end,
      set_operator = 'relational'
    })
  end
end
