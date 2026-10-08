--- Factions puts every character into a faction, which is also the team of its player.
-- A faction is a `Faction` object, normally defined in a file of the factions folder of a
-- schema or plugin. It sets the name, color, models and ranks of its members, whether they
-- choose a name, description and gender of their own, and whether a whitelist is needed to
-- join. The plugin makes the choice of a faction the first stage of character creation,
-- generates character names from the name template of the faction, groups the scoreboard by
-- faction, and adds commands that change factions, ranks and whitelists.
--
-- The `Factions` functions register and look up factions, and the `Player` extensions read and
-- change the faction, rank and whitelists of a player. The `OnPlayerFactionChanged` and
-- `OnRankChanged` hooks report changes, and `ShouldNameGenerate` can stop a name from being
-- generated. The 'faction' and 'rank' conditions are registered for the Conditions plugin.

PLUGIN:set_global('Factions')

Plugin.add_extra('factions')

require_relative 'cl_hooks'
require_relative 'sv_hooks'

--- Includes a plugin's factions folder when the 'factions' extra is being loaded.
-- @param extra [String name of the extra being loaded]
-- @param folder [String path of the plugin folder]
-- @return [Boolean true when the extra was handled here, otherwise nil]
function Factions:PluginIncludeFolder(extra, folder)
  if extra == 'factions' then
    self.include_factions(folder..'/factions/')

    return true
  end
end

--- Prevents faction name generation for bots.
-- @param target [Player]
-- @return [Boolean false for bots, otherwise nil]
function Factions:ShouldNameGenerate(target)
  if target:IsBot() then
    return false
  end
end

--- Registers the 'faction' and 'rank' conditions, which compare a player's faction and their
-- rank within a faction.
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
    check = function(target, data)
      if !data.operator or !data.faction_id then return false end

      return util.process_operator(data.operator, target:get_faction_id(), data.faction_id)
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
    check = function(target, data)
      if !data.operator or !data.rank or !data.faction_id then return false end
      if target:get_faction_id() != data.faction_id then return false end

      return util.process_operator(data.operator, target:get_rank(), data.rank)
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
