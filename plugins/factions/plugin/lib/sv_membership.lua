--- Server side of the memberships of factions. Nothing stores which faction a character is in:
-- `Factions.resolve_membership` works it out from what the player carries and wears, and from
-- the default faction of their species, and `Factions.refresh_membership` applies the result
-- whenever it may have changed. The plugin refreshes the membership when a character is
-- applied, when its items have been loaded, and on the next tick after anything that adds,
-- takes, moves, equips or unequips an item of the player (see `Factions.queue_refresh`). A
-- refresh that changes the faction calls the on_player_leave callback of the old faction and
-- the on_player_join callback of the new one, then runs PlayerFactionChanged. The plugin
-- forgets the membership of a player before a character is applied, when the active character
-- is dropped and when the player disconnects: that calls the on_player_leave callback of their
-- faction and runs no hook, so every applied character that is in a faction gets on_player_join
-- and `PlayerFactionChanged(target, faction, nil)` from its first resolution, and
-- on_player_leave when it stops being active.
--
-- Until the items of a character have been loaded, its membership is provisional: it is the
-- membership resolved last for that character, which is kept in its generic character data
-- for that purpose only. Bots, which have no items, keep the random faction they were given
-- the same way.
--
-- A character also keeps a record per faction in its generic character data, read and written
-- with `Factions.get_record` and `Factions.set_record`, for other systems to keep what they
-- know about a character in a faction. The plugin itself keeps only the rank in the default
-- faction of the species there; the rank in a faction granted by an item is in the data of
-- the item.

local IsValid = IsValid
local isstring = isstring
local istable = istable
local next = next
local tonumber = tonumber
local stored = Factions.stored

--- Key of the generic character data that holds the records of a character, by faction ID.
const records_key = 'faction_records'

--- Key of the generic character data that holds the membership resolved last for the
-- character, the provisional membership until its items are loaded.
const membership_key = 'faction_membership'

local pending = {}

--- Returns the record a character keeps for a faction. Server only.
-- @param character [Character]
-- @param faction_id [String]
-- @return [Map the values of the record by key, nil when the character has none for the
--   faction]
function Factions.get_record(character, faction_id)
  local records = Characters.get_custom_data(character, records_key)
  local record = istable(records) and records[faction_id]

  return istable(record) and record or nil
end

--- Sets a value in the record a character keeps for a faction, which is saved with the
-- character. A record without values is removed. Server only.
-- ```
-- Factions.set_record(character, 'citizen', 'rank', 2)
-- ```
-- @param character [Character]
-- @param faction_id [String]
-- @param key [String]
-- @param value [Any anything serializable; nil removes the key]
function Factions.set_record(character, faction_id, key, value)
  if !istable(character) or !isstring(faction_id) or !isstring(key) then return end

  local records = Characters.get_custom_data(character, records_key)

  records = istable(records) and records or {}

  local record = istable(records[faction_id]) and records[faction_id] or {}

  record[key] = value
  records[faction_id] = next(record) != nil ? record : nil

  Characters.set_custom_data(character, records_key, next(records) != nil ? records : nil)
end

--- Checks whether the items of the active character of a player have been loaded, which is
-- when their membership stops being provisional. Never true for bots. Server only.
-- @param target [Player]
-- @return [Boolean]
function Factions.has_items_loaded(target)
  local character = target:get_character()

  return character != nil and target.faction_items_character == character
end

--- Returns the faction and rank that the items of a player grant, among the items in their
-- own inventories whose faction is registered, belongs to the species of the player and is
-- granted by the item (see `Factions.item_grants`): the faction of the highest priority, the
-- one registered first among equals, at the highest rank its items grant.
-- @param target [Player]
-- @param species_id [String the species of the player]
-- @return [Faction, Number rank index, Item the granting item; nothing when no item grants
--   a faction]
local function item_membership(target, species_id)
  local best_faction, best_rank, best_item

  for _, item_obj in ipairs(target:get_items()) do
    local faction_table = isstring(item_obj.faction) and stored[item_obj.faction]

    if faction_table and faction_table.species == species_id and Factions.item_grants(item_obj, target) then
      local rank = Factions.get_item_rank(item_obj, faction_table)

      if !best_faction or faction_table.priority > best_faction.priority
      or (faction_table.priority == best_faction.priority and faction_table.team_id < best_faction.team_id) then
        best_faction, best_rank, best_item = faction_table, rank, item_obj
      elseif faction_table == best_faction and rank > best_rank then
        best_rank, best_item = rank, item_obj
      end
    end
  end

  return best_faction, best_rank, best_item
end

--- Returns the default faction of the species of a player, at the rank of the record of the
-- character for that faction, or at the default rank of the faction when the record has no
-- rank the faction has.
-- @param target [Player]
-- @param species [Species the species of the player, nil when it is not registered]
-- @return [Faction, Number rank index; nothing when the species has no default faction]
local function default_membership(target, species)
  local faction_table = Factions.get_default_faction(species)

  if !faction_table then return end

  local record = Factions.get_record(target:get_character(), faction_table.faction_id)
  local rank = record and tonumber(record.rank)

  if !rank or !faction_table:get_rank(rank) then
    rank = faction_table:get_default_rank()
  end

  return faction_table, rank
end

--- Returns the membership kept in the character data of a player, if its faction is
-- registered and belongs to the species of the player. A rank the faction does not have
-- becomes its default rank.
-- @param target [Player]
-- @param species_id [String the species of the player]
-- @return [Faction, Number rank index; nothing when nothing valid is kept]
local function stored_membership(target, species_id)
  local kept = Characters.get_custom_data(target:get_character(), membership_key)
  local faction_table = istable(kept) and stored[kept.faction]

  if !faction_table or faction_table.species != species_id then return end

  local rank = tonumber(kept.rank)

  if !rank or !faction_table:get_rank(rank) then
    rank = faction_table:get_default_rank()
  end

  return faction_table, rank
end

--- Keeps a membership in the data of a character, unless it is kept there already.
-- @param character [Character]
-- @param faction_table [Faction the faction, nil for none]
-- @param rank [Number rank index, nil for none]
local function store_membership(character, faction_table, rank)
  local kept = Characters.get_custom_data(character, membership_key)
  local faction_id = faction_table and faction_table.faction_id

  kept = istable(kept) and kept or nil

  if kept?.faction == faction_id and kept?.rank == rank then return end

  Characters.set_custom_data(character, membership_key, faction_id ? { faction = faction_id, rank = rank } : nil)
end

--- Keeps a membership in the data of a character as the one it has until its items have been
-- loaded, as for a new character that starts in a faction. It is replaced as soon as the
-- membership is resolved from the items. Server only.
-- @param character [Character]
-- @param faction_table [Faction]
-- @param rank=nil [Number rank index; the default rank of the faction without it]
function Factions.set_provisional_membership(character, faction_table, rank)
  store_membership(character, faction_table, rank or faction_table:get_default_rank())
end

--- Puts a player into a random faction of their species, kept in the data of their character
-- as their membership, unless a membership is kept there already. This is how a bot, which
-- has no items, keeps the faction it is given when it first spawns. Server only.
-- @param target [Player]
-- @return [Boolean true when a faction has been picked]
function Factions.keep_random_membership(target)
  local character = target:get_character()

  if !character or Characters.get_custom_data(character, membership_key) != nil then return false end

  local candidates = {}
  local species_id = target:get_species_id()

  for _, faction_table in pairs(stored) do
    if faction_table.species == species_id then
      candidates[#candidates + 1] = faction_table
    end
  end

  local faction_table = table.Random(candidates)

  if !faction_table then return false end

  Factions.set_provisional_membership(character, faction_table)

  return true
end

--- Works out which faction a player is a member of, and at which rank. Once the items of their
-- character have been loaded, it is the faction granted by their items (see
-- `Factions.item_grants`) or, without one, the default faction of their species at the rank
-- of the record of the character. Before that it is the membership kept in the character
-- data, or the default faction of the species when nothing valid is kept. A player without a
-- species default and without a granting item is in no faction. Server only.
-- @param target [Player]
-- @return [Faction the faction, Number the rank index, Item the item that grants the faction
--   (nil for the default faction of the species and while the membership is provisional);
--   nothing when the player is in no faction]
function Factions.resolve_membership(target)
  if !IsValid(target) or (!target:IsBot() and !target:is_character_loaded()) then return end

  local species_id = target:get_species_id()
  local species = Species.find_by_id(species_id)

  if Factions.has_items_loaded(target) then
    local faction_table, rank, item_obj = item_membership(target, species_id)

    if faction_table then
      return faction_table, rank, item_obj
    end
  else
    local faction_table, rank = stored_membership(target, species_id)

    if faction_table then
      return faction_table, rank
    end
  end

  return default_membership(target, species)
end

--- Resolves the membership of a player again and applies what has changed: the networked
-- `faction` and `rank`, the team, the on_player_leave and on_player_join callbacks of the
-- factions, the vitals, rank model and loadout (see `Factions.apply_membership`) and the
-- feelings of NPCs, followed by the PlayerFactionChanged hook when the faction has changed
-- or the PlayerRankChanged hook when only the rank has. Once the items of the character have
-- been loaded, the result is kept in its character data, for the next time it is loaded. The
-- display name of the character is refreshed in any case (see
-- `Characters.refresh_display_name`). Server only.
-- @param target [Player]
function Factions.refresh_membership(target)
  if !IsValid(target) then return end

  local faction_table, rank = Factions.resolve_membership(target)
  local old_faction = target:get_faction()
  local old_rank = target:get_nv('rank')

  if !faction_table then
    rank = nil
  end

  if Factions.has_items_loaded(target) then
    store_membership(target:get_character(), faction_table, rank)
  end

  if faction_table == old_faction and rank == old_rank then
    Characters.refresh_display_name(target)

    return
  end

  local faction_changed = faction_table != old_faction

  target:set_nv('faction', faction_table and faction_table.faction_id)
  target:set_nv('rank', rank)
  target:SetTeam(faction_table and faction_table.team_id or TEAM_UNASSIGNED)

  if faction_changed then
    if old_faction then
      old_faction:on_player_leave(target)
    end

    if faction_table then
      faction_table:on_player_join(target)
    end
  end

  Factions.apply_membership(target)

  if faction_changed then
    Factions.apply_npc_relations(target)

    --- Called on the server when the faction of a player has changed as their membership was
    -- resolved again (see `Factions.refresh_membership`): their networked faction and rank
    -- and their team have been updated, the on_player_leave and on_player_join callbacks of
    -- the factions have run, and the player has been given the weapons, maximum health and
    -- armor and rank model of the new faction and the feelings of NPCs toward it.
    -- @param target [Player]
    -- @param faction_table [Faction the faction the player is in now, nil when they are in
    --   none]
    -- @param old_faction [Faction the faction the player was in before, nil when they were in
    --   none]
    hook.Run('PlayerFactionChanged', target, faction_table, old_faction)
  else
    --- Called on the server when the rank of a player in their faction has changed as their
    -- membership was resolved again, such as after `Player:set_rank`: the rank has been
    -- networked and the player has been given the model, the weapons and the maximum health
    -- and armor of the rank.
    -- @param target [Player]
    -- @param rank [Number the new rank index]
    -- @param old_rank [Number the rank index before the change, nil when it was not known]
    hook.Run('PlayerRankChanged', target, rank, old_rank)
  end

  Characters.refresh_display_name(target)
end

--- Refreshes the membership of every player whose refresh was queued, once each.
local function run_pending()
  local targets = pending

  pending = {}

  for target in pairs(targets) do
    if IsValid(target) then
      Factions.refresh_membership(target)
    end
  end
end

--- Refreshes the membership of a player on the next tick, once however often it is queued
-- before then. The plugin queues a refresh whenever an item is added to, taken from or moved
-- between the inventories of a player, and whenever an item of a player is equipped or
-- unequipped, since the hooks of the Items plugin run at different moments of a move. Server
-- only.
-- @param target [Player nothing happens for anything else]
-- @see [Factions.refresh_membership]
function Factions.queue_refresh(target)
  if !IsValid(target) or !target:IsPlayer() then return end

  if next(pending) == nil then
    timer.Simple(0, run_pending)
  end

  pending[target] = true
end
