PLUGIN:set_global('Factions')

plugin.add_extra('factions')

util.include('cl_hooks.lua')
util.include('sv_hooks.lua')

function Factions:PluginIncludeFolder(extra, folder)
  if extra == 'factions' then
    faction.include_factions(folder..'/factions/')

    return true
  end
end

function Factions:ShouldNameGenerate(player)
  if player:IsBot() then
    return false
  end
end

function Factions:OnPluginsLoaded()
  if Doors then
    Doors:register_condition('faction', {
      name = t'doors.conditions.faction.name',
      text = t'doors.conditions.faction.text'..' %s %s',
      format = function(panel, data)
        local panel_data = panel.data
        local operator = util.operator_to_symbol(panel_data.operator) or t'doors.select_operator'
        local faction_name = t'doors.select_parameter'

        if panel_data.faction_id then
          faction_name = faction.find_by_id(panel_data.faction_id):get_name()
        end

        return string.format(data.text, operator, faction_name)
      end,
      icon = 'icon16/group.png',
      check = function(player, entity, data)
        if !data.operator or !data.faction_id then return false end

        return util.process_operator(data.operator, player:get_faction_id(), data.faction_id)
      end,
      set_parameters = function(id, data, panel, menu)
        panel:create_selector(data.name, 'doors.conditions.faction.message', 'doors.factions', faction.all(), 
        function(selector, _faction)
          selector:add_choice(t(_faction.name), function()
            panel.data.faction_id = _faction.faction_id
      
            panel.update()
          end)
        end)
      end,
      set_operator = 'equal'
    })

    Doors:register_condition('rank', {
      name = t'doors.conditions.rank.name',
      text = t'doors.conditions.rank.text'..' %s %s %s',
      format = function(panel, data)
        local panel_data = panel.data
        local operator = util.operator_to_symbol(panel_data.operator) or t'doors.select_operator'
        local faction_name = t'doors.select_parameter'
        local rank_name = t'doors.select_parameter'
  
        if panel_data.faction_id then
          local _faction = faction.find_by_id(panel_data.faction_id)
          faction_name = _faction:get_name()
  
          if panel_data.rank then
            rank_name = _faction:get_rank(panel_data.rank).id
          end
        end
  
        return string.format(data.text, faction_name, operator, rank_name)
      end,
      icon = 'icon16/award_star_gold_1.png',
      check = function(player, entity, data)
        if !data.operator or !data.rank or !data.faction_id then return false end
        if player:get_faction_id() != data.faction_id then return false end
  
        return util.process_operator(data.operator, player:get_rank(), data.rank)
      end,
      set_parameters = function(id, data, panel, menu)
        panel:create_selector(data.name, 'doors.conditions.faction.message', 'doors.factions', faction.all(), 
        function(faction_selector, _faction)
          if #_faction:get_ranks() == 0 then continue end
  
          faction_selector:add_choice(t(_faction.name), function()
            panel.data.faction_id = _faction.faction_id
      
            panel.update()

            panel:create_selector(data.name, 'doors.conditions.rank.message', 'doors.ranks', _faction:get_ranks(), 
            function(rank_selector, rank)
              rank_selector:add_choice(t(rank.name), function()
                panel.data.rank = rank.id
          
                panel.update()
              end)
            end)
          end)
        end)
      end,
      set_operator = 'relational'
    })
  end
end
