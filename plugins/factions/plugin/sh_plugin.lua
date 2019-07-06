PLUGIN:set_global('Factions')

Plugin.add_extra('factions')

require_relative 'cl_hooks'
require_relative 'sv_hooks'

function Factions:PluginIncludeFolder(extra, folder)
  if extra == 'factions' then
    self.include_factions(folder..'/factions/')

    return true
  end
end

function Factions:ShouldNameGenerate(player)
  if player:IsBot() then
    return false
  end
end

function Factions:RegisterConditions()
  Conditions:register_condition('faction', {
    name = 'condition.faction.name',
    text = 'condition.faction.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator)
      local faction_name

      if panel.data.faction_id then
        faction_name = self.find_by_id(panel.data.faction_id):get_name()
      end

      return { operator = operator, faction = faction_name }
    end,
    icon = 'icon16/group.png',
    check = function(player, data)
      if !data.operator or !data.faction_id then return false end

      return util.process_operator(data.operator, player:get_faction_id(), data.faction_id)
    end,
    set_parameters = function(id, data, panel, menu, parent)
      parent:create_selector(data.name, 'condition.faction.message', 'condition.factions', self.all(),
      function(selector, _faction)
        selector:add_choice(t(_faction.name), function()
          panel.data.faction_id = _faction.faction_id

          panel.update()
        end)
      end)
    end,
    set_operator = 'equal'
  })

  Conditions:register_condition('rank', {
    name = 'condition.rank.name',
    text = 'condition.rank.text',
    get_args = function(panel, data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local faction_name = ''
      local rank_name = ''

      if panel.data.faction_id then
        local _faction = faction.find_by_id(panel.data.faction_id)
        faction_name = _faction:get_name()

        if panel.data.rank then
          rank_name = _faction:get_rank(panel.data.rank).id
        end
      end

      return { operator = operator, faction = faction_name, rank = rank_name }
    end,
    icon = 'icon16/award_star_gold_1.png',
    check = function(player, data)
      if !data.operator or !data.rank or !data.faction_id then return false end
      if player:get_faction_id() != data.faction_id then return false end

      return util.process_operator(data.operator, player:get_rank(), data.rank)
    end,
    set_parameters = function(id, data, panel, menu, parent)
      parent:create_selector(data.name, 'condition.faction.message', 'condition.factions', self.all(),
      function(faction_selector, _faction)
        if #_faction:get_ranks() == 0 then return end

        faction_selector:add_choice(t(_faction.name), function()
          panel.data.faction_id = _faction.faction_id

          panel.update()

          parent:create_selector(data.name, 'condition.rank.message', 'condition.ranks', _faction:get_ranks(),
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
