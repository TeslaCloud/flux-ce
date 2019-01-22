PLUGIN:set_global('Characters')

util.include('cl_hooks.lua')
util.include('sv_plugin.lua')
util.include('sv_hooks.lua')
util.include('sh_enums.lua')

function Characters:OnPluginsLoaded()
  if Doors then
    Doors:register_condition('character', {
      name = t'doors.conditions.character.name',
      text = t'doors.conditions.character.text'..' %s %s',
      format = function(panel, data)
        local panel_data = panel.data
        local operator = util.operator_to_symbol(panel_data.operator) or t'doors.select_operator'
        local character_id = panel_data.character_id or t'doors.select_parameter'

        return string.format(data.text, operator, character_id)
      end,
      icon = 'icon16/user.png',
      check = function(player, entity, data)
        if !data.operator or !data.character_id then return false end

        return util.process_operator(data.operator, player:get_active_character_id(), data.character_id)
      end,
      set_parameters = function(id, data, panel, menu)
        panel:create_selector(data.name, 'doors.conditions.character.message', 'doors.characters', player.all(), 
        function(selector, player)
          local character = player:get_character()

          if character then
            selector:add_choice(player:name(), function()
              panel.data.character_id = character.character_id
        
              panel.update()
            end)
          end
        end)
      end,
      set_operator = 'equal'
    })
  end
end
