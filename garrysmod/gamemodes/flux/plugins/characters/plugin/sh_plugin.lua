PLUGIN:set_global('Characters')

util.include('cl_hooks.lua')
util.include('sv_plugin.lua')
util.include('sv_hooks.lua')
util.include('sh_enums.lua')

function Characters:RegisterConditions()
  Conditions:register_condition('character', {
    name = 'conditions.character.name',
    text = 'conditions.character.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local character_id = panel.data.character_id or ''

      return { operator, character_id }
    end,
    icon = 'icon16/user.png',
    check = function(player, data)
      if !data.operator or !data.character_id then return false end

      return util.process_operator(data.operator, player:get_active_character_id(), data.character_id)
    end,
    set_parameters = function(id, data, panel, menu, parent)
      parent:create_selector(data.name, 'conditions.character.message', 'conditions.characters', player.all(), 
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
