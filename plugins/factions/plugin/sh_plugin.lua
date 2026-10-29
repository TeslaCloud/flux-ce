--- Factions puts every character into a faction, which is also the team of its player.
-- A faction is a `Faction` object, normally defined in a file of the factions folder of a
-- schema or plugin. It sets the name, color, models and ranks of its members, whether they
-- choose a name, description and gender of their own, and whether a whitelist is needed to
-- join. The plugin makes the choice of a faction the first stage of character creation,
-- generates character names from the name template of the faction, groups the scoreboard by
-- faction, and adds commands that change factions, ranks and whitelists.
--
-- A faction can also limit how many of its members, or holders of one of its ranks, may be
-- online at once, which is checked when a character is loaded, and how many characters one
-- player may have in it, which is checked when a character is created. Its members spawn
-- with the weapons, the maximum health and the maximum armor that the faction and their rank
-- set, wear the model of their rank if it has one, and are liked, feared or hated by the NPC
-- classes that the faction names. A rank can let its holders promote and demote other
-- members with `/rank promote` and `/rank demote`, which staff with the 'manage_ranks'
-- permission may use on anyone.
--
-- The `Factions` functions register and look up factions, and the `Player` extensions read and
-- change the faction, rank and whitelists of a player. The `OnPlayerFactionChanged` and
-- `OnRankChanged` hooks report changes, `ShouldNameGenerate` can stop a name from being
-- generated, `GetFactionLimit` and `PlayerCanBypassFactionLimit` adjust the limits, and
-- `PlayerCanTransferFaction` can refuse a transfer by the SetFaction command. The plugin
-- answers `GetRandomCharacterName` from the random_names lists of a faction. The 'faction'
-- and 'rank' conditions are registered for the Conditions plugin, and the 'faction', 'rank'
-- and 'model' argument types for the completion of commands.

PLUGIN:set_global('Factions')

Plugin.add_extra('factions')

require_relative 'cl_hooks'
require_relative 'cl_nethooks'
require_relative 'sh_hooks'
require_relative 'sv_hooks'

--- Returns the factions of the players that a command argument names, the way the server
-- finds them: by their exact name or SteamID, or '^' for the actor.
-- @param actor [Player the player who is typing, nil for the server console]
-- @param target_arg [String the typed player argument]
-- @return [List<Faction> the factions, empty if the argument names nobody with a faction]
local function factions_of(actor, target_arg)
  local targets = target_arg == '^' and IsValid(actor) ? { actor } : player.find_exact(target_arg)
  local found, seen = {}, {}

  for _, target in ipairs(targets) do
    local faction_table = target:get_faction()

    if faction_table and !seen[faction_table] then
      seen[faction_table] = true
      found[#found + 1] = faction_table
    end
  end

  return found
end

local function suggested_factions(actor, args)
  local found = isstring(args[1]) and factions_of(actor, args[1]) or {}

  if #found == 0 then
    for _, faction_table in SortedPairs(Factions.all()) do
      found[#found + 1] = faction_table
    end
  end

  return found
end

local function complete_faction()
  local ids = {}

  for faction_id in pairs(Factions.all()) do
    ids[#ids + 1] = faction_id
  end

  table.sort(ids)

  return ids
end

--- Completes arguments of the 'rank' type with the ranks of the factions of the players named
-- by the first argument, or of every faction: the ID of each rank, or its index if the ID is
-- empty.
-- @param actor [Player the player who is typing, nil for the server console]
-- @param _partial [String the text typed for the argument so far]
-- @param args [List<String> the arguments typed before the completed one]
-- @return [List<String>]
local function complete_rank(actor, _partial, args)
  local values = {}

  for _, faction_table in ipairs(suggested_factions(actor, args)) do
    for index, rank in ipairs(faction_table:get_ranks()) do
      values[#values + 1] = (isstring(rank.id) and rank.id != '') and rank.id or tostring(index)
    end
  end

  return values
end

--- Completes arguments of the 'model' type with the models of the factions of the players
-- named by the first argument, or of every faction.
-- @param actor [Player the player who is typing, nil for the server console]
-- @param _partial [String the text typed for the argument so far]
-- @param args [List<String> the arguments typed before the completed one]
-- @return [List<String> model paths]
local function complete_model(actor, _partial, args)
  local values = {}

  for _, faction_table in ipairs(suggested_factions(actor, args)) do
    for _, models in SortedPairs(faction_table:get_models() or {}) do
      for _, model_path in ipairs(istable(models) and models or {}) do
        values[#values + 1] = model_path
      end
    end
  end

  return values
end

Flux.Command:add_completer('faction', complete_faction)
Flux.Command:add_completer('rank', complete_rank)
Flux.Command:add_completer('model', complete_model)

--- Registers the 'manage_ranks' permission, which lets staff promote and demote any member
-- of any faction, whatever their own rank.
function Factions:RegisterPermissions()
  Bolt:register_permission(
    'manage_ranks',
    'Manage faction ranks',
    'Grants access to promote and demote any character, regardless of the ranks.',
    'permission.categories.character_management'
  )
end

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
    get_args = function(panel, _data)
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
    set_parameters = function(_id, data, panel, _menu, parent)
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
    get_args = function(panel, _data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local faction_name = ''
      local rank_name = ''

      if panel.data.faction_id then
        local _faction = self.find_by_id(panel.data.faction_id)
        faction_name = _faction:get_name()

        local rank_table = select(2, _faction:find_rank(panel.data.rank))

        if rank_table then
          rank_name = rank_table.id
        end
      end

      return { operator = operator, faction = faction_name, rank = rank_name }
    end,
    icon = 'icon16/award_star_gold_1.png',
    check = function(target, data)
      if !data.operator or !data.rank or !data.faction_id then return false end
      if target:get_faction_id() != data.faction_id then return false end

      local rank_table = target:get_rank_table()
      local faction_table = self.find_by_id(data.faction_id)
      local rank = faction_table and faction_table:find_rank(data.rank)

      if !rank_table or !rank then return false end

      return util.process_operator(data.operator, target:get_rank(), rank)
    end,
    set_parameters = function(_id, data, panel, _menu, parent)
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
