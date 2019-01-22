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
  if Conditions then
    Conditions:register_condition('attribute', {
      name = 'conditions.attribute.name',
      text = 'conditions.attribute.text',
      get_args = function(panel, data)
        local attribute_name = ''
        local operator = util.operator_to_symbol(panel.data.operator) or ''
        local attribute_value = panel.data.attribute_value or ''

        if panel.data.attribute then
          attribute_name = attributes.find_by_id(panel.data.attribute).name
        end

        return { operator, attribute_name, attribute_value }
      end,
      icon = 'icon16/chart_bar.png',
      check = function(player, data)
        if !data.operator or !data.attribute or !data.attribute_value then return false end

        return util.process_operator(data.operator, player:get_attribute(data.attribute), tonumber(data.attribute_value))
      end,
      set_parameters = function(id, data, panel, menu, parent)
        parent:create_selector(data.name, 'conditions.attribute.message1', 'conditions.attributes', attributes.get_stored(), 
        function(selector, value)
          selector:add_choice(t(value.name), function()
            panel.data.attribute = value.attr_id
      
            panel.update()

            Derma_StringRequest(
              t(data.name),
              t'conditions.attribute.message2',
              '',
              function(text)
                panel.data.attribute_value = text
        
                panel.update()
              end)
          end)
        end)
      end,
      set_operator = 'relational'
    })
  end
end
