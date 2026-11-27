--- Factions makes every character a member of a faction, which is also the team of its player.
-- A faction is a `Faction` object, normally defined in a file of the factions folder of a
-- schema or plugin. It is what a character is recognized as: an organization with a name, a
-- color, ranks, a loadout, maximum health and armor, NPC relations, stat bonuses and the
-- name its members are shown under. Every faction belongs to one species of the Characters
-- plugin, `human` by default.
--
-- Nothing stores which faction a character is in. A player is a member because of what they
-- carry or wear: an item whose definition sets `ITEM.faction` grants that faction, an
-- equipable item while it is equipped and any other item while it is in one of the player's
-- own inventories (see `Factions.item_grants`), and the rank is in the data of that item, so
-- whoever holds the item holds the rank. Without such an item the player is a member of the
-- `default_faction` of their species, at the rank kept in the record of the character for
-- that faction (see `Factions.get_record`). Among the items of several factions the highest
-- `priority` wins, and the faction registered first among equals. The membership is resolved
-- again whenever it may have changed (see `Factions.refresh_membership`); until the items of
-- a character are loaded, the one resolved last for it stands in.
--
-- A whitelist for a faction restricts nobody: it adds an option to character creation, a new
-- character of the species of the faction that starts with its `kit`, the items that make
-- someone a member. The option of a species whose default faction is whitelisted is only
-- offered to players who have that whitelist. `/setfaction` hands out kits, `/rank` changes
-- ranks where the membership comes from, and `/whitelist` manages whitelists. A faction can
-- show its members under another name than the real name of their character, with a
-- `name_template` or a `Faction:get_display_name` of its own. Its members spawn with the
-- weapons, the maximum health and the maximum armor that the faction and their rank set, wear
-- the model of their rank if it has one, and are liked, feared or hated by the NPC classes
-- that the faction names. A rank can let its holders promote and demote other members with
-- `/rank promote` and `/rank demote`, which staff with the 'manage_ranks' permission may use on
-- anyone. The scoreboard is grouped by faction.
--
-- The `Factions` functions register and look up factions and resolve memberships, and the
-- `Player` extensions read the faction and rank of a player and change their rank and
-- whitelists. The `PlayerFactionChanged` and `PlayerRankChanged` hooks report changes, and
-- `PlayerCanTransferFaction` can refuse a kit given by the SetFaction command. The 'faction'
-- and 'rank' conditions are registered for the Conditions package, and the 'faction' and
-- 'rank' argument types for the completion of commands.

PLUGIN:set_global('Factions')

Plugin.add_extra('factions')

require_relative 'cl_hooks'
require_relative 'sh_hooks'
require_relative 'sv_hooks'

--- Returns the factions of the players that a command argument names (see
-- `Flux.Command:find_argument_players`).
-- @param actor [Player the player who is typing, nil for the server console]
-- @param target_arg [String the typed player argument]
-- @return [List<Faction> the factions, empty if the argument names nobody with a faction]
local function factions_of(actor, target_arg)
  local targets = Flux.Command:find_argument_players(actor, target_arg)
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

Flux.Command:add_completer('faction', complete_faction)
Flux.Command:add_completer('rank', complete_rank)

--- Registers the 'manage_ranks' permission, which lets staff promote and demote any member
-- of any faction, whatever their own rank.
function Factions:RegisterPermissions()
  Bolt:register_permission('manage_ranks', nil, nil, 'permission.categories.character_management')
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

--- Checks the definitions of the factions and species once every plugin, and with them every
-- faction and species, has been loaded.
-- @see [Factions.check_definitions]
function Factions:PluginsLoaded()
  self.check_definitions()
end

--- Registers the 'faction' and 'rank' conditions, which compare a player's faction and their
-- rank within a faction.
function Factions:RegisterConditions()
  Conditions:register_condition('faction', {
    name = 'condition.faction.name',
    text = 'condition.faction.text',
    get_args = function(panel, _data)
      local operator = util.operator_to_symbol(panel.data.operator) or ''
      local faction_name = self.find_by_id(panel.data.faction_id)?.:get_name() ?? ''

      return { operator = operator, faction = faction_name }
    end,
    icon = 'icon16/group.png',
    check = function(target, data)
      if !data.operator or !data.faction_id then return false end

      return util.process_operator(data.operator, target:get_faction_id() or '', data.faction_id)
    end,
    set_parameters = function(_id, data, panel, _menu, parent)
      parent:create_selector(data.name, 'condition.faction.message', 'condition.factions', self.all(),
      function(selector, faction_table)
        selector:add_choice(t(faction_table.name), function()
          panel.data.faction_id = faction_table.faction_id

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
      local faction_table = self.find_by_id(panel.data.faction_id)
      local faction_name = ''
      local rank_name = ''

      if faction_table then
        faction_name = faction_table:get_name()

        local rank_table = select(2, faction_table:find_rank(panel.data.rank))

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
      function(faction_selector, faction_table)
        if #faction_table:get_ranks() == 0 then return end

        faction_selector:add_choice(t(faction_table.name), function()
          panel.data.faction_id = faction_table.faction_id

          panel.update()

          parent:create_selector(data.name, 'condition.rank.message', 'condition.ranks', faction_table:get_ranks(),
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
