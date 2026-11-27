--- The shared `Factions` functions: they register and look up factions, read the resolved
-- membership of a player, tell which items grant a faction and at which rank, and who may
-- promote and demote whom. The loader of faction definition files is here as well. How the
-- server resolves memberships is in `sv_membership.lua`, what the members of a faction get
-- from it in `sv_faction.lua`, and the player methods that read and change the faction, rank
-- and whitelists of a player are in `lib/meta`.
-- @module [Factions]

local IsValid = IsValid
local isfunction = isfunction
local isnumber = isnumber
local isstring = isstring
local istable = istable
local tonumber = tonumber

if !Factions then
  PLUGIN:set_global 'Factions'
end

local stored = Factions.stored or {}
local count = Factions.count or 0
Factions.stored = stored
Factions.count = count

--- Returns the faction of a player and their rank in it, as their membership was last resolved
-- (see `Factions.refresh_membership`), if the player counts as a member: bots always do, other
-- players only while they have an active character.
-- @param target [Player]
-- @return [Faction the faction and Number the rank index (-1 on the client when no rank has
--   been networked); nothing for anyone who is not a member of a registered faction]
function Factions.get_membership(target)
  if !IsValid(target) or !target:IsPlayer() then return end
  if !target:IsBot() and !target:is_character_loaded() then return end

  local faction_table = target:get_faction()

  if !faction_table then return end

  return faction_table, target:get_rank()
end

--- Turns the can_promote or can_demote field of a rank into a rank index.
-- @param faction_table [Faction the faction of the rank]
-- @param rank [Number index of the rank that has the field]
-- @param value [Number/String/Boolean rank index, rank ID, or true for the rank below]
-- @return [Number rank index, or nil if the field grants nothing]
local function get_authority(faction_table, rank, value)
  if value == true then
    return rank - 1
  elseif isnumber(value) then
    return value
  elseif isstring(value) then
    return (faction_table:find_rank(value))
  end
end

--- Registers a faction: fills in the default name and description (the 'faction.unknown.*'
-- phrases), color, species, priority, kit, loadout and NPC relations, and sets up its team.
-- The team ID also tells the order in which the factions were registered. The species of the
-- faction, the default factions of the species and the animation classes of the rank models
-- are checked and assigned once every plugin has been loaded (see `Factions.check_definitions`).
-- ```
-- local faction = Faction.new('citizen')
-- faction.name = 'Citizen'
--
-- -- Same as faction:register()
-- Factions.add_faction(faction.faction_id, faction)
-- ```
-- @param id [String faction ID, normalized with to_id]
-- @param data [Faction the faction to register; receives faction_id and team_id]
-- @see [Faction#register]
function Factions.add_faction(id, data)
  if !id or !data then return end

  data.faction_id = id:to_id() or (data.name and data.name:to_id())
  data.name = data.name or 'faction.unknown.title'
  data.description = data.description or 'faction.unknown.description'
  data.color = data.color or Color(255, 255, 255)
  data.species = isstring(data.species) and data.species or 'human'
  data.priority = tonumber(data.priority) or 0
  data.kit = istable(data.kit) and data.kit or {}
  data.loadout = istable(data.loadout) and data.loadout or {}
  data.npc_relations = istable(data.npc_relations) and data.npc_relations or {}

  team.SetUp(count + 1, data.name, data.color)

  data.team_id = count + 1

  stored[data.faction_id] = data
  count += 1
end

--- Assigns the animation class of each model of the ranks of a faction: a single model path
-- gets the model_class of the rank and nothing without one; each path of a table of models
-- gets the model_class of the rank, or else the class the species of the faction has for the
-- same key.
-- @param faction_table [Faction]
local function assign_rank_model_classes(faction_table)
  local species = faction_table:get_species()
  local species_classes = species and species.model_classes or {}

  for _, rank_table in ipairs(faction_table.rank) do
    local model = rank_table.model

    if isstring(model) then
      if rank_table.model_class then
        Flux.Anim:set_model_class(model, rank_table.model_class)
      end
    elseif istable(model) then
      for gender, model_path in pairs(model) do
        local model_class = rank_table.model_class or species_classes[gender]

        if isstring(model_path) and model_class then
          Flux.Anim:set_model_class(model_path, model_class)
        end
      end
    end
  end
end

--- Checks the definitions of the factions and species once all of them have been registered,
-- since the species and factions folders of plugins and the schema load in no fixed order:
-- warns about a faction whose species is not registered, a faction with an NPC relation
-- that is not a disposition and a species whose default_faction is not a registered faction
-- of that species, and assigns the animation classes of the rank models. The plugin calls it
-- when all plugins have been loaded, on both realms.
function Factions.check_definitions()
  for faction_id, faction_table in pairs(stored) do
    if !faction_table:get_species() then
      ErrorNoHalt('[Flux:Factions] The \''..faction_id..'\' faction belongs to the species \''..
        tostring(faction_table.species)..'\', which is not registered!\n')
    end

    for npc_class, value in pairs(faction_table.npc_relations) do
      if !faction_table:get_npc_disposition(npc_class) then
        ErrorNoHalt('[Flux:Factions] The \''..faction_id..'\' faction has an invalid relation \''..
          tostring(value)..'\' towards \''..tostring(npc_class)..'\'!\n')
      end
    end

    assign_rank_model_classes(faction_table)
  end

  for _, species in ipairs(Species.get_list()) do
    local default_faction = species.default_faction

    if default_faction != nil and Factions.get_default_faction(species) == nil then
      ErrorNoHalt('[Flux:Factions] The default faction \''..tostring(default_faction)..'\' of the \''..
        species.species_id..'\' species is not a registered faction of that species!\n')
    end
  end
end

--- Returns the faction registered under the exact ID.
-- @param id [String faction ID]
-- @return [Faction the faction, or nil if it is not registered]
function Factions.find_by_id(id)
  return stored[id]
end

--- Returns the default faction of a species: the registered faction its default_faction field
-- names, if that faction belongs to the species. A character of the species who carries
-- nothing that grants a faction is a member of it.
-- @param species [Species]
-- @return [Faction the faction, nil when the species has no valid default faction]
function Factions.get_default_faction(species)
  local faction_table = species and stored[species.default_faction]

  if faction_table and faction_table.species == species.species_id then
    return faction_table
  end
end

--- Returns every connected player whose resolved faction is the given one.
-- @param id [String faction ID]
-- @return [List<Player>]
function Factions.get_players(id)
  local players = {}

  for _, client in player.Iterator() do
    if client:get_faction_id() == id then
      players[#players + 1] = client
    end
  end

  return players
end

--- Finds a faction by its whole ID or its whole name, ignoring letter case. The name may be
-- given as the language phrase the faction is registered with or as its translation. An ID
-- is matched before any name.
-- @param name [String faction ID or name]
-- @return [Faction/Boolean the faction, or false if no faction has this ID or name]
function Factions.find(name)
  if !isstring(name) then return false end

  local lowered = name:utf8lower()

  for faction_id, faction_table in pairs(stored) do
    if faction_id:utf8lower() == lowered then
      return faction_table
    end
  end

  for _, faction_table in pairs(stored) do
    local faction_name = tostring(faction_table.name)

    if faction_name:utf8lower() == lowered or t(faction_name):utf8lower() == lowered then
      return faction_table
    end
  end

  return false
end

--- Returns every registered faction.
-- @return [Map factions keyed by faction ID]
function Factions.all()
  return stored
end

--- Returns every registered faction in the order in which they were registered.
-- @return [List<Faction>]
function Factions.get_list()
  local list = {}

  for _, faction_table in pairs(stored) do
    list[#list + 1] = faction_table
  end

  table.sort(list, |a, b| -> a.team_id < b.team_id)

  return list
end

--- Checks whether an item grants its faction to the player who has it in one of their own
-- inventories. An item whose definition has a grants_faction(owner) method decides itself;
-- otherwise an equipable item grants it while it is equipped and any other item while it is
-- carried. Whether the item names a registered faction is not looked at here. The plugin
-- resolves memberships again whenever an item of a player is added, taken or moved; an item
-- whose answer changes while it stays where it is calls `Factions.queue_refresh` for its owner.
-- ```
-- -- items/sh_police_badge.lua: grants the faction only while the badge is shown.
-- ITEM.faction = 'police'
--
-- function ITEM:grants_faction(_owner)
--   return self:get_data('shown') == true
-- end
-- ```
-- @param item_obj [Item an item in one of the inventories of the player]
-- @param owner [Player the player who has the item]
-- @return [Boolean]
function Factions.item_grants(item_obj, owner)
  if isfunction(item_obj.grants_faction) then
    return item_obj:grants_faction(owner) == true
  end

  if isfunction(item_obj.is_equipped) then
    return item_obj:is_equipped() == true
  end

  return true
end

--- Returns the rank that an item grants in its faction: the rank index in the rank field of
-- its data, else the faction_rank field of its definition (a rank ID or index), else the
-- default rank of the faction. A rank the faction does not have is skipped.
-- @param item_obj [Item]
-- @param faction_table [Faction the faction the item grants]
-- @return [Number rank index]
function Factions.get_item_rank(item_obj, faction_table)
  local rank = tonumber(item_obj:get_data('rank'))

  if rank and faction_table:get_rank(rank) then
    return rank
  end

  local start_rank = faction_table:find_rank(item_obj.faction_rank)

  return start_rank or faction_table:get_default_rank()
end

--- Returns the model that a player uses because of their rank, instead of the model of
-- their character.
-- @param target [Player]
-- @return [String model path, or nil if the rank of the player does not change the model]
-- @see [Faction#get_rank_model]
function Factions.get_rank_model(target)
  local faction_table, rank = Factions.get_membership(target)

  if faction_table then
    return faction_table:get_rank_model(rank, target:get_gender())
  end
end

--- Checks whether the rank of a player lets them promote another player. Both have to be
-- members of the same faction, the rank of the actor has to have the can_promote field, and
-- the rank the target would be promoted to must exist and be no higher than that field
-- allows. Nobody may promote themselves. The permissions of staff are not looked at here:
-- the `/rank promote` command accepts either.
-- ```
-- FACTION:add_rank('recruit')
-- FACTION:add_rank('officer')
-- FACTION:add_rank('sergeant', 'Sgt.', { can_promote = 'officer' })
--
-- -- A sergeant may promote a recruit to officer, but not an officer to sergeant.
-- if Factions.can_promote(sergeant, recruit) then
--   recruit:promote_rank()
-- end
-- ```
-- @param actor [Player the player who wants to promote]
-- @param target [Player the player who would be promoted]
-- @return [Boolean]
-- @see [Factions.can_demote]
function Factions.can_promote(actor, target)
  if actor == target then return false end

  local faction_table, rank = Factions.get_membership(actor)
  local target_faction, target_rank = Factions.get_membership(target)

  if !faction_table or faction_table != target_faction or !isnumber(target_rank) then return false end

  local rank_table = faction_table:get_rank(rank)
  local highest = rank_table and get_authority(faction_table, rank, rank_table.can_promote)

  if !highest or !faction_table:get_rank(target_rank) then return false end

  local new_rank = target_rank + 1

  return faction_table:get_rank(new_rank) != nil and new_rank <= highest
end

--- Checks whether the rank of a player lets them demote another player. Both have to be
-- members of the same faction, the rank of the actor has to have the can_demote field, and
-- the target must hold a rank that is not the lowest one and is no higher than that field
-- allows. Nobody may demote themselves. The permissions of staff are not looked at here:
-- the `/rank demote` command accepts either.
-- @param actor [Player the player who wants to demote]
-- @param target [Player the player who would be demoted]
-- @return [Boolean]
-- @see [Factions.can_promote]
function Factions.can_demote(actor, target)
  if actor == target then return false end

  local faction_table, rank = Factions.get_membership(actor)
  local target_faction, target_rank = Factions.get_membership(target)

  if !faction_table or faction_table != target_faction or !isnumber(target_rank) then return false end

  local rank_table = faction_table:get_rank(rank)
  local highest = rank_table and get_authority(faction_table, rank, rank_table.can_demote)

  if !highest or !faction_table:get_rank(target_rank) then return false end

  return target_rank > 1 and target_rank <= highest
end

--- Includes every file of a folder as a faction definition. Each file gets a fresh FACTION
-- global, a Faction named after the file, that is registered once the file has run.
-- ```
-- -- factions/sh_police.lua, registered as 'police'
-- FACTION.name = 'Police'
-- FACTION.description = 'Keeps order in the city.'
-- FACTION.color = Color(60, 100, 200)
-- FACTION.whitelisted = true
-- FACTION.kit = { 'police_uniform' }
-- FACTION.name_template = '{rank} {name}'
-- FACTION:add_rank('recruit', 'Rct.')
-- FACTION:add_rank('officer', 'Ofc.')
-- ```
-- @param directory [String folder to include files from]
function Factions.include_factions(directory)
  Pipeline.include_folder('faction', directory)
end

Pipeline.register('faction', function(id, file_name, _pipe)
  FACTION = Faction.new(id)

  require_relative(file_name)

  FACTION:register()
  FACTION = nil
end)
