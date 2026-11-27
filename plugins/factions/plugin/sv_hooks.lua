--- Server side of the Factions plugin: resolves the membership of a player again when their
-- character is applied, when its items have been loaded and on the next tick after any of
-- their items has been added, taken or moved; keeps bots in a random faction; gives the
-- members of a faction their team, weapons, maximum health and armor, rank model and the
-- feelings of NPCs whenever they spawn or their membership changes; starts new characters as
-- members of the faction of their creation option, giving them its kit the first time they are
-- loaded; and loads and networks the whitelists of players.
--
-- The membership of a player is forgotten when a character is about to be applied, when the
-- active character is dropped and when the player disconnects: the on_player_leave callback
-- of their faction runs then, without PlayerFactionChanged. The first resolution after a
-- character has been applied therefore starts from no faction: when it finds one, it calls
-- the on_player_join callback of that faction and runs `PlayerFactionChanged(target, faction,
-- nil)`.

Cable.check_networked_string('fl_faction_creation_refused')

--- Key of the generic character data that holds the kit a new character is still to be given:
-- the faction and the rank.
const pending_kit_key = 'faction_kit'

--- Forgets the membership of a player: undoes the feelings of NPCs, forgets the rank model and
-- that the items of the character have been loaded, clears the networked faction and rank,
-- puts the player into the unassigned team and then calls the on_player_leave callback of the
-- faction they were in. PlayerFactionChanged is not run.
-- @param target [Player]
local function forget_membership(target)
  local faction_table = target:get_faction()

  Factions.reset_npc_relations(target)

  target.faction_model = nil
  target.faction_items_character = nil

  target:set_nv('faction', nil)
  target:set_nv('rank', nil)
  target:SetTeam(TEAM_UNASSIGNED)

  if faction_table then
    faction_table:on_player_leave(target)
  end
end

--- Returns the rank that a new member of a faction holds once they wear its kit: the highest
-- rank that the faction_rank fields of the kit items that grant the faction name, the
-- default rank of the faction for an item without one or when no kit item grants it.
-- @param faction_table [Faction]
-- @return [Number rank index]
local function kit_rank(faction_table)
  local default_rank = faction_table:get_default_rank()
  local best

  for _, item_id in ipairs(faction_table:get_kit()) do
    local template = Item.find_by_id(item_id)

    if template and template.faction == faction_table.faction_id then
      local rank = faction_table:find_rank(template.faction_rank) or default_rank

      best = best and math.max(best, rank) or rank
    end
  end

  return best or default_rank
end

--- Puts a bot that has no faction yet into a random faction of its species, which it keeps
-- (see `Factions.keep_random_membership`), and sets the team of every spawning member and
-- gives them the maximum health and armor of their faction and rank, filled up.
-- @param actor [Player]
function Factions:PostPlayerSpawn(actor)
  if actor:IsBot() then
    self.keep_random_membership(actor)
    self.refresh_membership(actor)
  end

  local faction_table = actor:get_faction()

  if faction_table then
    actor:SetTeam(faction_table.team_id)
  end

  if actor:IsBot() or actor:is_character_loaded() then
    self.apply_vitals(actor, true)
  end
end

--- Gives a spawning player the weapons of their faction and rank on top of the default
-- loadout. The record of the weapons given before is dropped first, as the gamemode has
-- just stripped every weapon of the player. The hook runs inside Player:Spawn, so the ammo
-- that the Characters plugin restores once the player has spawned is set on top of these
-- weapons.
-- @param actor [Player]
-- @param _loadout [List<String> weapon classes the player has been given]
function Factions:PlayerLoadoutGiven(actor, _loadout)
  actor.faction_weapons = nil

  self.give_loadout(actor)
end

--- Makes a spawning player use the model of their rank, if the rank has one.
-- @param actor [Player]
-- @return [String model path of the rank, nil to leave the choice of the model to others]
function Factions:GetPlayerModel(actor)
  local model = self.get_rank_model(actor)

  if model then
    actor.faction_model = model

    return model
  end
end

--- Resolves the membership of a player whose character is about to be applied, before they
-- are spawned, so that their team, spawn point and loadout are those of their faction. The
-- membership of the character that was active before is forgotten first, which calls the
-- on_player_leave callback of its faction, so the resolution starts from no faction: when it
-- finds one, it calls the on_player_join callback of that faction and runs
-- PlayerFactionChanged with no old faction, whatever the previous character was. The items
-- of the character are not loaded yet, so the membership is provisional (see
-- `Factions.resolve_membership`).
-- @param owner [Player]
-- @param _character [Character]
function Factions:PreLoadCharacter(owner, _character)
  forget_membership(owner)

  self.refresh_membership(owner)
end

--- Gives the player what their faction grants them in the world once the Characters plugin
-- has spawned them, given them the model of the character and restored their saved health,
-- armor and ammo: the weapons, the maximum health and armor (full armor if the character had
-- none saved), the model of the rank over that of the character and the feelings of NPCs.
-- @param owner [Player]
-- @param character [Character]
function Factions:PostLoadCharacter(owner, character)
  self.apply_membership(owner)
  self.apply_npc_relations(owner)

  local faction_table, rank = self.get_membership(owner)
  local max_armor = faction_table and faction_table:get_max_armor(rank)

  if max_armor and tonumber(character.armor) == nil then
    owner:SetArmor(max_armor)
  end
end

--- Ends the provisional membership of a player once the items of their active character have
-- been loaded, and resolves it from the items.
-- @param owner [Player]
-- @param character [Character the character whose items have been loaded]
-- @param _items [List<Item>]
function Factions:CharacterItemsLoaded(owner, character, _items)
  if owner:get_character() != character then return end

  owner.faction_items_character = character

  self.refresh_membership(owner)
end

--- Resolves the membership of the player whose inventory an item has been put into.
-- @param _item_obj [Item]
-- @param inventory [Inventory]
-- @param _x [Number]
-- @param _y [Number]
function Factions:ItemAdded(_item_obj, inventory, _x, _y)
  self.queue_refresh(inventory.owner)
end

--- Resolves the membership of the player whose inventory an item has been taken out of.
-- @param _item_obj [Item]
-- @param inventory [Inventory]
function Factions:ItemTaken(_item_obj, inventory)
  self.queue_refresh(inventory.owner)
end

--- Resolves the memberships of the players whose inventories an item has left and entered,
-- which is how equipping and unequipping an item changes a membership.
-- @param _item_obj [Item]
-- @param new_inventory [Inventory nil when the item has left for the world or been removed]
-- @param old_inventory [Inventory nil when the item has been picked up]
function Factions:ItemTransferred(_item_obj, new_inventory, old_inventory)
  if new_inventory then
    self.queue_refresh(new_inventory.owner)
  end

  if old_inventory then
    self.queue_refresh(old_inventory.owner)
  end
end

--- Takes the faction of a character away from the player who drops it: clears the networked
-- faction and rank, forgets the rank model, undoes the feelings of NPCs, puts the player back
-- into the unassigned team and calls the on_player_leave callback of the faction.
-- PlayerFactionChanged is not run.
-- @param owner [Player]
-- @param _character [Character the character that is being dropped]
function Factions:ActiveCharacterCleared(owner, _character)
  forget_membership(owner)
end

--- Takes the faction a character starts in from the creation option the player has chosen,
-- never from what the client has sent, and discards the rank, which a client has no say in.
-- @param _actor [Player]
-- @param data [Map character creation data, changed in place]
-- @param option [Map the creation option the player has chosen]
function Factions:PreCreateCharacter(_actor, data, option)
  data.rank = nil
  data.faction = option?.data?.faction
end

--- Lets the on_character_create callback of the faction a character starts in refuse the
-- character, with the reason the callback gives.
-- @param actor [Player]
-- @param data [Map character creation data]
-- @return [Number CHAR_ERR_FACTION_REFUSED or the code the callback of the faction returned
--   when the character is refused, otherwise nil]
function Factions:PlayerCreateCharacter(actor, data)
  local faction_table = isstring(data.faction) and self.find_by_id(data.faction)

  if !faction_table then return end

  local result, reason, arguments = faction_table:on_character_create(actor, data)

  if isnumber(result) and result != CHAR_SUCCESS then
    return result
  elseif result == false then
    if isstring(reason) then
      Cable.send(actor, 'fl_faction_creation_refused', reason, arguments)
    end

    return CHAR_ERR_FACTION_REFUSED
  end
end

--- Starts a new character as a member of the faction of its creation option. For the default
-- faction of its species, the rank the on_character_create callback has set goes into the
-- record of the character; any other faction leaves a note to give the character the kit of
-- the faction, at that rank, the first time it is loaded (see Factions:AddDefaultItems). The
-- faction is the provisional membership of the character until its items have been loaded
-- (see `Factions.set_provisional_membership`), at the rank the callback has set or else the
-- rank the character will hold: the one its kit grants for a kit faction, the default rank of
-- the faction otherwise. The character starts with the maximum health and armor of the
-- faction and rank when they set them.
-- @param _owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data]
function Factions:PostCreateCharacter(_owner, char, char_data)
  local faction_table = isstring(char_data.faction) and self.find_by_id(char_data.faction)

  if !faction_table then return end

  local faction_id = faction_table.faction_id
  local rank = tonumber(char_data.rank)

  if !rank or !faction_table:get_rank(rank) then
    rank = nil
  end

  local start_rank = rank

  if faction_table == self.get_default_faction(Species.find_by_id(char.species)) then
    if rank then
      self.set_record(char, faction_id, 'rank', rank)
    end
  else
    Characters.set_custom_data(char, pending_kit_key, { faction = faction_id, rank = rank })

    start_rank = rank or kit_rank(faction_table)
  end

  start_rank = start_rank or faction_table:get_default_rank()

  local max_health = faction_table:get_max_health(start_rank)
  local max_armor = faction_table:get_max_armor(start_rank)

  self.set_provisional_membership(char, faction_table, start_rank)

  if max_health then
    char.health = max_health
  end

  if max_armor then
    char.armor = max_armor
  end
end

--- Gives a new character the kit of the faction it was created to start in, the first time it
-- is loaded, and tells the player about the items of the kit that could not be given.
-- @param owner [Player]
-- @param char [Character the new character]
function Factions:AddDefaultItems(owner, char)
  local pending = Characters.get_custom_data(char, pending_kit_key)

  if !istable(pending) then return end

  Characters.set_custom_data(char, pending_kit_key, nil)

  local faction_table = self.find_by_id(pending.faction)

  if !faction_table then return end

  local missing = self.give_kit(owner, faction_table, tonumber(pending.rank))

  if #missing > 0 then
    owner:notify('notification.faction_kit_incomplete', { items = table.concat(missing, ', ') })
  end
end

--- Loads the whitelists of a player together with their user record.
-- @param preloads [Map relations of the user record, changed in place]
function Factions:AdjustPlayerRecordPreloads(preloads)
  preloads[#preloads + 1] = 'whitelists'
end

--- Networks to the player the IDs of the factions they are whitelisted for.
-- @param actor [Player]
-- @param record [User the player's database record]
function Factions:PlayerRestored(actor, record)
  if record.whitelists then
    local whitelists = {}

    for _, whitelist in pairs(record.whitelists) do
      table.insert(whitelists, whitelist.faction_id)
    end

    actor:set_private_nv('whitelists', whitelists)
  end
end

--- Forgets the membership of a disconnecting player: makes NPCs forget what their faction has
-- made them feel and calls the on_player_leave callback of the faction. PlayerFactionChanged
-- is not run.
-- @param actor [Player]
function Factions:PlayerDisconnected(actor)
  forget_membership(actor)
end

--- Makes a newly created NPC feel about the players the way their factions say. This is done
-- on the next tick, once the NPC has spawned and set up its own relationships.
-- @param entity [Entity]
function Factions:OnEntityCreated(entity)
  if IsValid(entity) and entity:IsNPC() then
    timer.Simple(0, function()
      self.setup_npc(entity)
    end)
  end
end

--- Keeps the model of the rank on a player whose character model has been changed.
-- @param owner [Player]
-- @param _char [Character the active character, nil if the player has none]
-- @param _model [String the new model of the character]
-- @param _old_model [String the model that was networked before the change]
function Factions:CharacterModelChanged(owner, _char, _model, _old_model)
  self.apply_model(owner)
end

--- Shows a member of a faction under the name that the faction gives them (see
-- `Faction:get_display_name`).
-- @param target [Player]
-- @param _character [Character the active character of the player]
-- @return [String the display name, nil for the real name]
function Factions:GetCharacterDisplayName(target, _character)
  local faction_table, rank = self.get_membership(target)

  if faction_table then
    return faction_table:get_display_name(target, target:name(true), faction_table:get_rank(rank))
  end
end
